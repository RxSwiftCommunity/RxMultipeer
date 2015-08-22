import Foundation
import RxSwift
import MultipeerConnectivity

public class MultipeerConnectivitySession : NSObject, Session {

  typealias I = MCPeerID

  public let _session: MCSession
  public let serviceType: String

  let advertiser: MCNearbyServiceAdvertiser
  let browser: MCNearbyServiceBrowser

  public var iden: MCPeerID { return _session.myPeerID }
  public var meta: [String: String]? { return self.advertiser.discoveryInfo as? [String: String] }

  public init(
      displayName: String,
      serviceType: String,
      meta: [String: String]? = nil,
      encryptionPreference: MCEncryptionPreference = .None) {
    let peerId = MCPeerID(displayName: displayName)
    self.serviceType = serviceType
    self._session = MCSession(peer: peerId,
                             securityIdentity: nil,
                             encryptionPreference: encryptionPreference)

    self.advertiser = MCNearbyServiceAdvertiser(
        peer: self._session.myPeerID,
        discoveryInfo: meta,
        serviceType: self.serviceType)

    self.browser = MCNearbyServiceBrowser(
        peer: self._session.myPeerID,
        serviceType: self.serviceType)

    super.init()

    self._session.delegate = self
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
    >- map { [unowned self] (client, context, handler) in
      return (client, context, { (accept: Bool) in handler(accept, self._session) })
    }
  }

  public func startAdvertising() {
    advertiser.startAdvertisingPeer()
  }

  public func stopAdvertising() {
    advertiser.stopAdvertisingPeer()
  }

  var _nearbyPeers: [(MCPeerID, [String: String]?)] = [] {
    didSet { sendNext(rx_nearbyPeers, _nearbyPeers) }
  }

  let rx_nearbyPeers: Variable<[(MCPeerID, [String: String]?)]> = Variable([])

  public func nearbyPeers() -> Observable<[(MCPeerID, [String: String]?)]> {
    return rx_nearbyPeers
  }

  public func startBrowsing() {
    browser.startBrowsingForPeers()
  }

  public func stopBrowsing() {
    browser.stopBrowsingForPeers()
    // Because we are aggregating found and lost peers in order
    // to get nearby peers, we should start with a clean slate when
    // browsing is kicked off again.
    sendNext(rx_nearbyPeers, [])
  }

  public func connect(peer: MCPeerID, context: [String: AnyObject]?, timeout: NSTimeInterval) {
    let data: NSData?
    if let c = context {
      var err: NSError?
      data = NSJSONSerialization.dataWithJSONObject(
        c, options: NSJSONWritingOptions(), error: &err)
    } else{
      data = nil
    }

    browser.invitePeer(peer,
                       toSession: self._session,
                       withContext: data,
                       timeout: timeout)
  }

  public func disconnect() {
    self._session.disconnect()
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

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  public func send(other: MCPeerID,
                   _ data: NSData,
                   _ mode: MCSessionSendDataMode) -> Observable<()> {
    return create { observer in
      var err: NSError?
      self._session.sendData(data, toPeers: [other], withMode: mode, error: &err)
      if let e = err {
        sendError(observer, e)
      } else {
        sendCompleted(observer)
      }

      // There's no way to cancel this operation,
      // so do nothing on dispose.
      return AnonymousDisposable {}
    }
  }

  public func send(other: MCPeerID,
                   name: String,
                   url: NSURL,
                   _ mode: MCSessionSendDataMode) -> Observable<()> {
    return create { observer in
      let progress = self._session.sendResourceAtURL(url, withName: name, toPeer: other) { (err) in
        if let e = err { sendError(observer, err) }
        else { sendCompleted(observer) }
      }

      return AnonymousDisposable {
        if progress.cancellable {
          progress.cancel()
        }
      }
    }
  }

}

extension MultipeerConnectivitySession : MCNearbyServiceAdvertiserDelegate {

  public func advertiser(advertiser: MCNearbyServiceAdvertiser,
                         didReceiveInvitationFromPeer peerID: MCPeerID,
                         withContext context: NSData?,
                         invitationHandler: ((Bool, MCSession!) -> Void)) {
    let json: AnyObject?
    if let c = context {
      var err: NSError?
      json = NSJSONSerialization.JSONObjectWithData(
        c, options: NSJSONReadingOptions(), error: &err)
    } else {
      json = nil
    }

    sendNext(rx_incomingConnections, (peerID, json as? [String: AnyObject], invitationHandler))
  }

  public func advertiser(advertiser: MCNearbyServiceAdvertiser,
                         didNotStartAdvertisingPeer err: NSError) {
    sendNext(rx_connectionErrors, err)
  }

}

extension MultipeerConnectivitySession : MCNearbyServiceBrowserDelegate {

  public func browser(browser: MCNearbyServiceBrowser,
                      foundPeer peerId: MCPeerID,
                      withDiscoveryInfo info: [NSObject: AnyObject]?) {
    // Get a unique list of peers
    var result: [(MCPeerID, [String: String]?)] = []
    for o in (self._nearbyPeers + [(peerId, info as? [String: String])]) {
      if find(result.map { $0.0 }, o.0) == nil {
        result = result + [o]
      }
    }

    self._nearbyPeers = result
  }

  public func browser(browser: MCNearbyServiceBrowser,
                      lostPeer peerId: MCPeerID) {
    self._nearbyPeers = self._nearbyPeers.filter { (id, _) in
      id != peerId
    }
  }

  public func browser(browser: MCNearbyServiceBrowser,
                      didNotStartBrowsingForPeers err: NSError) {
    sendNext(rx_connectionErrors, err)
  }

}

extension MultipeerConnectivitySession : MCSessionDelegate {

  public func session(session: MCSession,
                      peer peerID: MCPeerID,
                      didChangeState state: MCSessionState) {
    switch state {
    case .Connected: sendNext(rx_connectedPeer, peerID)
    // Called for failed connections as well, but we'll allow for that.
    case .NotConnected: sendNext(rx_disconnectedPeer, peerID)
    default: break
    }
  }

  public func session(session: MCSession,
                      didReceiveData data: NSData,
                      fromPeer peerID: MCPeerID) {
    sendNext(rx_data, (peerID, data))
  }

  public func session(session: MCSession,
                      didStartReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      withProgress progress: NSProgress) {
    sendNext(rx_resource, (peerID, name, .Progress(progress)))
  }

  public func session(session: MCSession,
                      didFinishReceivingResourceWithName name: String,
                      fromPeer peerID: MCPeerID,
                      atURL url: NSURL,
                      withError err: NSError?) {
    if let e = err {
      sendNext(rx_resource, (peerID, name, .Errored(e)))
      return
    }

    sendNext(rx_resource, (peerID, name, .Finished(url)))
  }

  public func session(session: MCSession,
                      didReceiveStream stream: NSInputStream,
                      withName streamName: String,
                      fromPeer peerID: MCPeerID) {
    // No stream support yet - what's the best way to do streams
    // in Rx? Wrap them in Observables? hmmm
  }

}
