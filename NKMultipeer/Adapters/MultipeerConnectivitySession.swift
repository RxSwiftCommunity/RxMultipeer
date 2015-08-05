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

  public init(
      displayName: String,
      serviceType: String,
      encryptionPreference: MCEncryptionPreference = .None) {
    let peerId = MCPeerID(displayName: displayName)
    self.serviceType = serviceType
    self._session = MCSession(peer: peerId,
                             securityIdentity: nil,
                             encryptionPreference: encryptionPreference)

    self.advertiser = MCNearbyServiceAdvertiser(
        peer: self._session.myPeerID,
        discoveryInfo: nil,
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

  var rx_incomingConnections: PublishSubject<(MCPeerID, AnyObject?, (Bool, MCSession) -> Void)> = PublishSubject()

  public func incomingConnections() -> Observable<(MCPeerID, AnyObject?, (Bool) -> ())> {
    return rx_incomingConnections
    >- map { [unowned self] (client, meta, handler) in
      return (client, meta, { (accept: Bool) in handler(accept, self._session) })
    }
  }

  public func startAdvertising() {
    advertiser.startAdvertisingPeer()
  }

  public func stopAdvertising() {
    advertiser.stopAdvertisingPeer()
  }

  var _nearbyPeers: [(MCPeerID, AnyObject?)] = [] {
    didSet { sendNext(rx_nearbyPeers, _nearbyPeers) }
  }

  let rx_nearbyPeers: Variable<[(MCPeerID, AnyObject?)]> = Variable([])

  public func nearbyPeers() -> Observable<[(MCPeerID, AnyObject?)]> {
    return rx_nearbyPeers
  }

  public func startBrowsing() {
    browser.startBrowsingForPeers()
  }

  public func stopBrowsing() {
    browser.stopBrowsingForPeers()
  }

  public func connect(peer: MCPeerID, meta: AnyObject?, timeout: NSTimeInterval) {
    browser.invitePeer(peer,
                       toSession: self._session,
                       withContext: meta as? NSData,
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
    sendNext(rx_incomingConnections, (peerID, context, invitationHandler))
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
    self._nearbyPeers = self._nearbyPeers + [(peerId, info)]
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
