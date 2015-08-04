
import MultipeerConnectivity
import Foundation
import RxSwift

enum PeerState {
    case Connected
    case Disconnected
}

// It will work with any underlying object as long as they conform to the
// `Session` protocol.
public class Client {

  public var iden: ClientIden
  public var meta: AnyObject?

  public init(iden: ClientIden, meta: AnyObject? = nil) {
    self.iden = iden
    self.meta = meta
  }

}

public class CurrentClient : Client {

  // All state should be stored in the session
  public var session: Session

  let _connections: Observable<[Client]>

  public init(session: Session) {
    self.session = session

    // A list of connections is inferred by looking at
    // `connectedPeer` and `disconnectedPeer` from the underlying session.
    self._connections = returnElements(
        session.connectedPeer() >- map { ($0, PeerState.Connected) },
        session.disconnectedPeer() >- map { ($0, PeerState.Disconnected) })
    >- merge
    >- scan([]) { (connections: [Client], cs) in
      let client = cs.0
      let state = cs.1
      switch state {
      case .Connected:
        for c in connections { if c.iden == client.iden { return connections } }
        return connections + [client]
      case .Disconnected:
        return connections.filter { !$0.iden.isIdenticalTo(client.iden) }
      }
    }
    >- variable

    super.init(iden: session.iden)
  }

  public func connections() -> Observable<[Client]> {
    return _connections
  }

  public func connectedPeer() -> Observable<Client> {
    return session.connectedPeer()
  }

  public func disconnectedPeer() -> Observable<Client> {
    return session.disconnectedPeer()
  }

  // Advertising and connecting

  public func incomingConnections() -> Observable<(Client, (Bool) -> ())> {
    return session.incomingConnections()
  }

  public func nearbyPeers() -> Observable<[Client]> {
    return session.nearbyPeers()
  }

  public func startAdvertising() {
    session.startAdvertising()
  }

  public func stopAdvertising() {
    session.stopAdvertising()
  }

  public func startBrowsing() {
    session.startBrowsing()
  }

  public func stopBrowsing() {
    session.stopBrowsing()
  }

  public func connect(peer: Client, meta: AnyObject? = nil, timeout: NSTimeInterval = 12) {
    return session.connect(peer, meta: meta, timeout: timeout)
  }

  public func disconnect() {
    return session.disconnect()
  }

  public func connectionErrors() -> Observable<NSError> {
    return session.connectionErrors()
  }

  // Sending Data

  public func send
  (other: Client,
   _ string: String,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    return session.send(other, string, mode)
  }

  public func send
  (other: Client,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    return session.send(other, name: name, url: url, mode)
  }

  // Receiving data

  public func receive() -> Observable<String> {
    return session.receive()
  }

  public func receive() -> Observable<(String, NSURL)> {
    return session.receive()
  }

}
