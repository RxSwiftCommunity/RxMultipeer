import Foundation
import RxSwift
import RxCocoa
import MultipeerConnectivity

/// A RxMultipeer adapter for Apple's MultipeerConnectivity framework.
open class MultipeerConnectivitySession : NSObject, Session {

  public typealias I = MCPeerID

  open let session: MCSession
  open let serviceType: String

  fileprivate let disposeBag = DisposeBag()

  fileprivate let advertiser: MCNearbyServiceAdvertiser
  fileprivate let browser: MCNearbyServiceBrowser

  fileprivate let _incomingConnections: PublishSubject<(MCPeerID, [String: Any]?, (Bool, MCSession?) -> Void)> = PublishSubject()
  fileprivate let _incomingCertificateVerifications: PublishSubject<(MCPeerID, [Any]?, (Bool) -> Void)> = PublishSubject()
  fileprivate let _connections = Variable<[MCPeerID]>([])
  fileprivate let _nearbyPeers: Variable<[(MCPeerID, [String: String]?)]> = Variable([])
  fileprivate let _connectionErrors: PublishSubject<Error> = PublishSubject()
  fileprivate let _receivedData: PublishSubject<(MCPeerID, Data)> = PublishSubject()
  fileprivate let _receivedResource: PublishSubject<(MCPeerID, String, ResourceState)> = PublishSubject()
  fileprivate let _receivedStreams = PublishSubject<(MCPeerID, String, InputStream)>()

  open var iden: MCPeerID { return session.myPeerID }
  open var meta: [String: String]? { return self.advertiser.discoveryInfo }

  /// - Parameters:
  ///   - displayName: Name to display to nearby peers
  ///   - serviceType: The scope of the multipeer connectivity service, e.g `com.rxmultipeer.example`
  ///   - meta: Additional data that nearby peers can read when browsing
  ///   - idenCacheKey: The key to use to store the generated session identity.
  ///     By default a new `MCPeerID` is generated for each new session, however
  ///     it may be desirable to recycle existing idens with the same
  ///     `displayName` in order to prevent weird MultipeerConnectivity bugs.
  ///     [Read this SO answer for more information](http://goo.gl/mXlQj0)
  ///   - encryptionPreference: The session's encryption requirement
  public init(
      displayName: String,
      serviceType: String,
      meta: [String: String]? = nil,
      idenCacheKey: String? = nil,
      securityIdentity: [Any]? = nil,
      encryptionPreference: MCEncryptionPreference = .none) {

    let peerId = MultipeerConnectivitySession.getRecycledPeerID(forKey: idenCacheKey,
                                                                displayName: displayName)

    self.serviceType = serviceType
    self.session = MCSession(peer: peerId,
                             securityIdentity: securityIdentity,
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

  /// Given an iden cache key, retrieve either the existing serialized `MCPeerID`
  /// or generate a new one.
  ///
  /// It will return an existing `MCPeerID` when there is both a cache hit and the display names
  /// are identical. Otherwise, it will create a new one.
  open static func getRecycledPeerID(forKey key: String?, displayName: String) -> MCPeerID {
    let defaults = UserDefaults.standard
    if let k = key,
       let d = defaults.data(forKey: k),
       let p = NSKeyedUnarchiver.unarchiveObject(with: d) as? MCPeerID,
       p.displayName == displayName {
      return p
    }

    let iden = MCPeerID(displayName: displayName)

    if let k = key {
      defaults.set(NSKeyedArchiver.archivedData(withRootObject: iden), forKey: k)
    }

    return iden
  }

  /// - Seealso: `MCNearbyServiceAdvertiser.startAdvertisingPeer()`
  open func startAdvertising() {
    advertiser.startAdvertisingPeer()
  }

  /// - Seealso: `MCNearbyServiceAdvertiser.stopAdvertisingPeer()`
  open func stopAdvertising() {
    advertiser.stopAdvertisingPeer()
  }

  open func connections() -> Observable<[MCPeerID]> {
    return _connections.asObservable()
  }

  open func nearbyPeers() -> Observable<[(MCPeerID, [String: String]?)]> {
    return _nearbyPeers.asObservable()
  }

  /// - Seealso: `MCNearbyServiceBrowser.startBrowsingForPeers()`
  open func startBrowsing() {
    browser.startBrowsingForPeers()
  }

  /// - Seealso: `MCNearbyServiceBrowser.stopBrowsingForPeers()`
  open func stopBrowsing() {
    browser.stopBrowsingForPeers()
    // Because we are aggregating found and lost peers in order
    // to get nearby peers, we should start with a clean slate when
    // browsing is kicked off again.
    _nearbyPeers.value = []
  }

  open func connect(_ peer: MCPeerID, context: [String: Any]?, timeout: TimeInterval) {
    let data: Data?
    if let c = context {
      data = try? JSONSerialization.data(
        withJSONObject: c, options: JSONSerialization.WritingOptions())
    } else {
      data = nil
    }

    browser.invitePeer(
        peer,
        to: self.session,
        withContext: data,
        timeout: timeout)
  }

  open func incomingConnections() -> Observable<(MCPeerID, [String: Any]?, (Bool) -> ())> {
    return _incomingConnections
    .map { [unowned self] (client, context, handler) in
      return (client, context, { (accept: Bool) in handler(accept, self.session) })
    }
  }

  open func incomingCertificateVerifications() -> Observable<(I, [Any]?, (Bool) -> Void)> {
    return _incomingCertificateVerifications
  }

  open func disconnect() {
    self.session.disconnect()
  }

  open func connectionErrors() -> Observable<Error> {
    return _connectionErrors
  }

  open func receive() -> Observable<(MCPeerID, Data)> {
    return _receivedData
  }

  open func receive() -> Observable<(MCPeerID, String, ResourceState)> {
    return _receivedResource
      .map { (p, n, s) -> Observable<(MCPeerID, String, ResourceState)> in
        switch s {
        case .progress(let progress):
          return progress
            .rx.observe(Double.self, "fractionCompleted", retainSelf: false)
            .map { _ in (p, n, s) }
        default:
          return Observable.just((p, n, s))
        }
      }
      .merge()
  }

  open func receive(
    fromPeer other: MCPeerID,
    streamName: String,
    runLoop: RunLoop = RunLoop.main,
    maxLength: Int = 512)
    -> Observable<[UInt8]> {

    return _receivedStreams
      .filter { (c, n, _) in c == other && n == streamName }
      .map { $2 }
      .map { (stream) in
        Observable.create { observer in
          var delegate: NSStreamDelegateProxy?
          delegate = NSStreamDelegateProxy { (stream, event) in
            if event.contains(Stream.Event.hasBytesAvailable) {
              guard let s = stream as? InputStream else { return }
              var buffer = [UInt8](repeating: 0, count: maxLength)
              let readBytes = s.read(&buffer, maxLength: maxLength)
              if readBytes > 0 {
                observer.on(.next(Array(buffer[0..<readBytes])))
              }
            }

            if event.contains(Stream.Event.errorOccurred) {
              observer.on(.error(stream.streamError ?? RxMultipeerError.unknownError))
            }

            if event.contains(Stream.Event.endEncountered) {
              observer.on(.completed)
            }
          }

          stream.open()
          stream.delegate = delegate
          stream.schedule(in: runLoop, forMode: RunLoopMode.defaultRunLoopMode)

          return Disposables.create {
            stream.delegate = nil
            delegate = nil
            stream.close()
          }
        }
      }
      .switchLatest()

  }

  open func send(toPeer other: MCPeerID,
                 data: Data,
                 mode: MCSessionSendDataMode) -> Observable<()> {
    return Observable.create { observer in
      do {
        try self.session.send(data, toPeers: [other], with: mode)
        observer.on(.next(()))
        observer.on(.completed)
      } catch let error {
        observer.on(.error(error))
      }

      // There's no way to cancel this operation,
      // so do nothing on dispose.
      return Disposables.create {}
    }
  }

  open func send(toPeer other: MCPeerID,
                 name: String,
                 resource url: URL,
                 mode: MCSessionSendDataMode) -> Observable<Progress> {
    return Observable.create { observer in
      let progress = self.session.sendResource(at: url, withName: name, toPeer: other) { (err) in
        if let e = err { observer.on(.error(e)) }
        else {
          observer.on(.completed)
        }
      }

      let progressDisposable = progress?.rx.observe(Double.self, "fractionCompleted", retainSelf: false)
        .subscribe(onNext: { (_: Double?) in observer.on(.next(progress!)) })

      return CompositeDisposable(
          progressDisposable ?? Disposables.create { },
          Disposables.create {
            if let cancellable = progress?.isCancellable {
              if cancellable == true {
                progress?.cancel()
              }
            }
          })
    }
  }

  open func send(
      toPeer other: MCPeerID,
      streamName: String,
      runLoop: RunLoop = RunLoop.main)
      -> Observable<([UInt8]) -> Void> {

    return Observable.create { observer in
      var stream: OutputStream?
      var delegate: NSStreamDelegateProxy?

      do {
        stream = try self.session.startStream(withName: streamName, toPeer: other)
        delegate = NSStreamDelegateProxy { (s, event) in
          guard let stream = s as? OutputStream else { return }

          if event.contains(Stream.Event.hasSpaceAvailable) {
            observer.on(.next({ d in
              d.withUnsafeBufferPointer {
                if let baseAddress = $0.baseAddress {
                  stream.write(baseAddress, maxLength: d.count)
                }
              }
            }))
          }

          if event.contains(Stream.Event.errorOccurred) {
            observer.on(.error(stream.streamError ?? RxMultipeerError.unknownError))
          }

          if event.contains(Stream.Event.endEncountered) {
            observer.on(.completed)
          }
        }

        stream?.delegate = delegate
        stream?.schedule(in: runLoop, forMode: RunLoopMode.defaultRunLoopMode)
        stream?.open()
      } catch let e {
        observer.on(.error(e))
      }

      return Disposables.create {
        stream?.delegate = nil
        stream?.close()
        delegate = nil
      }
    }
  }

}

private class NSStreamDelegateProxy : NSObject, StreamDelegate {

  let handler: (Stream, Stream.Event) -> ()

  init(handler: @escaping (Stream, Stream.Event) -> ()) {
    self.handler = handler
  }

  @objc func stream(_ stream: Stream, handle event: Stream.Event) {
    handler(stream, event)
  }

}

extension MultipeerConnectivitySession : MCNearbyServiceAdvertiserDelegate {

  public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                         didReceiveInvitationFromPeer peerID: MCPeerID,
                         withContext context: Data?,
                         invitationHandler: (@escaping (Bool, MCSession?) -> Void)) {
    var json: Any? = nil
    if let c = context {
      json = try? JSONSerialization.jsonObject(with: c)
    }

    let jsonCast = json as? [String: Any]
    _incomingConnections.on(.next(peerID, jsonCast, invitationHandler))
  }

  public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                         didNotStartAdvertisingPeer err: Error) {
    _connectionErrors.on(.next(err))
  }

}

extension MultipeerConnectivitySession : MCNearbyServiceBrowserDelegate {

  public func browser(_ browser: MCNearbyServiceBrowser,
                      foundPeer peerId: MCPeerID,
                      withDiscoveryInfo info: [String: String]?) {
    // Get a unique list of peers
    var result: [(MCPeerID, [String: String]?)] = []
    for o in (self._nearbyPeers.value + [(peerId, info)]) {
      if (result.map { $0.0 }).index(of: o.0) == nil {
        result = result + [o]
      }
    }

    self._nearbyPeers.value = result
  }

  public func browser(_ browser: MCNearbyServiceBrowser,
                      lostPeer peerId: MCPeerID) {
    self._nearbyPeers.value = self._nearbyPeers.value.filter { (id, _) in
      id != peerId
    }
  }

  public func browser(_ browser: MCNearbyServiceBrowser,
                      didNotStartBrowsingForPeers err: Error) {
    _connectionErrors.on(.next(err))
  }

}

extension MultipeerConnectivitySession : MCSessionDelegate {

  public func session(_ session: MCSession,
                      peer peerID: MCPeerID,
                      didChange state: MCSessionState) {
    _connections.value = session.connectedPeers
  }

  public func session(_ session: MCSession,
                      didReceive data: Data,
                      fromPeer peerID: MCPeerID) {
    _receivedData.on(.next(peerID, data))
  }

  public func session(_ session: MCSession,
                      didStartReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      with progress: Progress) {
    _receivedResource.on(.next(peerID, name, .progress(progress)))
  }

  public func session(_ session: MCSession,
                      didFinishReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      at url: URL,
                      withError err: Error?) {
    if let e = err as? CustomStringConvertible {
      _receivedResource.on(
        .next(
          peerID,
          name,
          ResourceState.errored(RxMultipeerError.resourceError(e.description))))
      return
    } else if err != nil {
      _receivedResource.on(
        .next(
          peerID,
          name,
          ResourceState.errored(RxMultipeerError.resourceError("Unknown"))))
      return
    }

    _receivedResource.on(.next(peerID, name, .finished(url)))
  }

  public func session(_ session: MCSession,
                      didReceive stream: InputStream,
                      withName streamName: String,
                      fromPeer peerID: MCPeerID) {
    _receivedStreams.on(.next(peerID, streamName, stream))
  }

  public func session(_: MCSession,
                      didReceiveCertificate certificateChain: [Any]?,
                      fromPeer peerID: MCPeerID,
                      certificateHandler: @escaping (Bool) -> Void) {
    _incomingCertificateVerifications.on(
      .next(peerID,
            certificateChain,
            certificateHandler))
  }

}
