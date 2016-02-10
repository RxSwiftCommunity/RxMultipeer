import Foundation
import RxSwift
import RxCocoa
import MultipeerConnectivity

public class MultipeerConnectivitySession : NSObject, Session {

  public typealias I = MCPeerID

  public let session: MCSession
  public let serviceType: String

  private let disposeBag = DisposeBag()

  let advertiser: MCNearbyServiceAdvertiser
  let browser: MCNearbyServiceBrowser

  public var iden: MCPeerID { return session.myPeerID }
  public var meta: [String: String]? { return self.advertiser.discoveryInfo }

  public init(
      displayName: String,
      serviceType: String,
      meta: [String: String]? = nil,
      encryptionPreference: MCEncryptionPreference = .None) {
    let peerId = MCPeerID(displayName: displayName)
    self.serviceType = serviceType
    self.session = MCSession(peer: peerId,
                             securityIdentity: nil,
                             encryptionPreference: encryptionPreference)

    self.advertiser = MCNearbyServiceAdvertiser(
        peer: self.session.myPeerID,
        discoveryInfo: meta,
        serviceType: self.serviceType)

    self.browser = MCNearbyServiceBrowser(
        peer: self.session.myPeerID,
        serviceType: self.serviceType)

    super.init()

    self.session.delegate = self
    self.advertiser.delegate = self
    self.browser.delegate = self
  }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_connectedPeer: PublishSubject<MCPeerID> = PublishSubject()

  public func connectedPeer() -> Observable<MCPeerID> {
    return rx_connectedPeer
  }

  let rx_disconnectedPeer: PublishSubject<MCPeerID> = PublishSubject()

  public func disconnectedPeer() -> Observable<MCPeerID> {
    return rx_disconnectedPeer
  }

  var rx_incomingConnections: PublishSubject<(MCPeerID, [String: AnyObject]?, (Bool, MCSession) -> Void)> = PublishSubject()

  public func incomingConnections() -> Observable<(MCPeerID, [String: AnyObject]?, (Bool) -> ())> {
    return rx_incomingConnections
    .map { [unowned self] (client, context, handler) in
      return (client, context, { (accept: Bool) in handler(accept, self.session) })
    }
  }

  public func startAdvertising() {
    advertiser.startAdvertisingPeer()
  }

  public func stopAdvertising() {
    advertiser.stopAdvertisingPeer()
  }

  let rx_connections = Variable<[MCPeerID]>([])

  public func connections() -> Observable<[MCPeerID]> {
    return rx_connections.asObservable()
  }

  let rx_nearbyPeers: Variable<[(MCPeerID, [String: String]?)]> = Variable([])

  public func nearbyPeers() -> Observable<[(MCPeerID, [String: String]?)]> {
    return rx_nearbyPeers.asObservable()
  }

  public func startBrowsing() {
    browser.startBrowsingForPeers()
  }

  public func stopBrowsing() {
    browser.stopBrowsingForPeers()
    // Because we are aggregating found and lost peers in order
    // to get nearby peers, we should start with a clean slate when
    // browsing is kicked off again.
    rx_nearbyPeers.value = []
  }

  public func connect(peer: MCPeerID, context: [String: AnyObject]?, timeout: NSTimeInterval) {
    let data: NSData?
    if let c = context {
      data = try? NSJSONSerialization.dataWithJSONObject(
        c, options: NSJSONWritingOptions())
    } else {
      data = nil
    }

    browser.invitePeer(peer,
                       toSession: self.session,
                       withContext: data,
                       timeout: timeout)
  }

  public func disconnect() {
    self.session.disconnect()
  }

  let rx_connectionErrors: PublishSubject<NSError> = PublishSubject()

  public func connectionErrors() -> Observable<NSError> {
    return rx_connectionErrors
  }

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_data: PublishSubject<(MCPeerID, NSData)> = PublishSubject()

  public func receive() -> Observable<(MCPeerID, NSData)> {
    return rx_data
  }

  let rx_resource: PublishSubject<(MCPeerID, String, ResourceState)> = PublishSubject()

  public func receive() -> Observable<(MCPeerID, String, ResourceState)> {
    return rx_resource
  }

  let rx_receivedStreams = PublishSubject<(MCPeerID, String, NSInputStream)>()

  public func receive(
    other: MCPeerID,
    streamName: String,
    runLoop: NSRunLoop = NSRunLoop.mainRunLoop(),
    maxLength: Int = 512)
    -> Observable<[UInt8]> {

    return rx_receivedStreams
      .filter { (c, n, _) in c == other && n == streamName }
      .map { $2 }
      .map { (stream) in
        Observable.create { observer in
          var delegate: NSStreamDelegateProxy?
          delegate = NSStreamDelegateProxy { (stream, event) in
            if event.contains(NSStreamEvent.HasBytesAvailable) {
              guard let s = stream as? NSInputStream else { return }
              var buffer = [UInt8](count: maxLength, repeatedValue: 0)
              let readBytes = s.read(&buffer, maxLength: maxLength)
              if readBytes > 0 {
                observer.on(.Next(Array(buffer[0..<readBytes])))
              }
            }

            if event.contains(NSStreamEvent.ErrorOccurred) {
              observer.on(.Error(stream.streamError ?? NKMultipeerError.UnknownError))
            }

            if event.contains(NSStreamEvent.EndEncountered) {
              observer.on(.Completed)
            }
          }

          stream.open()
          stream.delegate = delegate
          stream.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)

          return AnonymousDisposable {
            stream.delegate = nil
            delegate = nil
            stream.close()
          }
        }
      }
      .switchLatest()

  }

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  public func send(other: MCPeerID,
                   _ data: NSData,
                   _ mode: MCSessionSendDataMode) -> Observable<()> {
    return Observable.create { observer in
      do {
        try self.session.sendData(data, toPeers: [other], withMode: mode)
        observer.on(.Next(()))
        observer.on(.Completed)
      } catch let error {
        observer.on(.Error(error))
      }

      // There's no way to cancel this operation,
      // so do nothing on dispose.
      return AnonymousDisposable {}
    }
  }

  public func send(other: MCPeerID,
                   name: String,
                   url: NSURL,
                   _ mode: MCSessionSendDataMode) -> Observable<NSProgress> {
    return Observable.create { observer in
      let progress = self.session.sendResourceAtURL(url, withName: name, toPeer: other) { (err) in
        if let e = err { observer.on(.Error(e)) }
        else {
          observer.on(.Completed)
        }
      }

      let progressDisposable = progress?.rx_observe(Double.self, "fractionCompleted", retainSelf: false)
        .subscribeNext { (_: Double?) in observer.on(.Next(progress!)) }

      return CompositeDisposable(
          progressDisposable ?? AnonymousDisposable { },
          AnonymousDisposable {
            if let cancellable = progress?.cancellable {
              if cancellable == true {
                progress?.cancel()
              }
            }
          })
    }
  }

  public func send(
      other: MCPeerID,
      streamName: String,
      runLoop: NSRunLoop = NSRunLoop.mainRunLoop())
      -> Observable<([UInt8]) -> Void> {

    return Observable.create { observer in
      var stream: NSOutputStream?
      var delegate: NSStreamDelegateProxy?

      do {
        stream = try self.session.startStreamWithName(streamName, toPeer: other)
        delegate = NSStreamDelegateProxy { (s, event) in
          guard let stream = s as? NSOutputStream else { return }

          if event.contains(NSStreamEvent.HasSpaceAvailable) {
            observer.on(.Next({ d in
              d.withUnsafeBufferPointer {
                stream.write($0.baseAddress, maxLength: d.count)
              }
            }))
          }

          if event.contains(NSStreamEvent.ErrorOccurred) {
            observer.on(.Error(stream.streamError ?? NKMultipeerError.UnknownError))
          }

          if event.contains(NSStreamEvent.EndEncountered) {
            observer.on(.Completed)
          }
        }

        stream?.delegate = delegate
        stream?.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        stream?.open()
      } catch let e {
        observer.on(.Error(e))
      }

      return AnonymousDisposable {
        stream?.delegate = nil
        stream?.close()
        delegate = nil
      }
    }
  }

  public class NSStreamDelegateProxy : NSObject, NSStreamDelegate {

    let handler: (NSStream, NSStreamEvent) -> ()

    public init(handler: (NSStream, NSStreamEvent) -> ()) {
      self.handler = handler
    }

    @objc public func stream(stream: NSStream, handleEvent event: NSStreamEvent) {
      handler(stream, event)
    }

  }

}

extension MultipeerConnectivitySession : MCNearbyServiceAdvertiserDelegate {

  public func advertiser(advertiser: MCNearbyServiceAdvertiser,
                         didReceiveInvitationFromPeer peerID: MCPeerID,
                         withContext context: NSData?,
                         invitationHandler: ((Bool, MCSession) -> Void)) {
    let json: AnyObject?
    if let c = context {
      json = try? NSJSONSerialization.JSONObjectWithData(
        c, options: NSJSONReadingOptions())
    } else {
      json = nil
    }

    rx_incomingConnections.on(.Next(
      peerID,
      json as? [String: AnyObject],
      invitationHandler
    ))
  }

  public func advertiser(advertiser: MCNearbyServiceAdvertiser,
                         didNotStartAdvertisingPeer err: NSError) {
    rx_connectionErrors.on(.Next(err))
  }

}

extension MultipeerConnectivitySession : MCNearbyServiceBrowserDelegate {

  public func browser(browser: MCNearbyServiceBrowser,
                      foundPeer peerId: MCPeerID,
                      withDiscoveryInfo info: [String: String]?) {
    // Get a unique list of peers
    var result: [(MCPeerID, [String: String]?)] = []
    for o in (self.rx_nearbyPeers.value + [(peerId, info)]) {
      if (result.map { $0.0 }).indexOf(o.0) == nil {
        result = result + [o]
      }
    }

    self.rx_nearbyPeers.value = result
  }

  public func browser(browser: MCNearbyServiceBrowser,
                      lostPeer peerId: MCPeerID) {
    self.rx_nearbyPeers.value = self.rx_nearbyPeers.value.filter { (id, _) in
      id != peerId
    }
  }

  public func browser(browser: MCNearbyServiceBrowser,
                      didNotStartBrowsingForPeers err: NSError) {
    rx_connectionErrors.on(.Next(err))
  }

}

extension MultipeerConnectivitySession : MCSessionDelegate {

  public func session(session: MCSession,
                      peer peerID: MCPeerID,
                      didChangeState state: MCSessionState) {
    rx_connections.value = session.connectedPeers
    switch state {
    case .Connected: rx_connectedPeer.on(.Next(peerID))
    // Called for failed connections as well, but we'll allow for that.
    case .NotConnected: rx_disconnectedPeer.on(.Next(peerID))
    default: break
    }
  }

  public func session(session: MCSession,
                      didReceiveData data: NSData,
                      fromPeer peerID: MCPeerID) {
    rx_data.on(.Next(peerID, data))
  }

  public func session(session: MCSession,
                      didStartReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      withProgress progress: NSProgress) {
    rx_resource.on(.Next(peerID, name, .Progress(progress)))
  }

  public func session(session: MCSession,
                      didFinishReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      atURL url: NSURL,
                      withError err: NSError?) {
    if let e = err {
      rx_resource.on(.Next(peerID, name, .Errored(e)))
      return
    }

    rx_resource.on(.Next(peerID, name, .Finished(url)))
  }

  public func session(session: MCSession,
                      didReceiveStream stream: NSInputStream,
                      withName streamName: String,
                      fromPeer peerID: MCPeerID) {
    self.rx_receivedStreams.on(.Next(peerID, streamName, stream))
  }

}
