
import MultipeerConnectivity
import Foundation
import RxSwift

// It will work with any underlying object as long as they conform to the
// `Session` protocol.
public class Client<I: Equatable> {

  public var iden: I
  public var meta: AnyObject?

  public init(iden: I, meta: AnyObject? = nil) {
    self.iden = iden
    self.meta = meta
  }

}

public class CurrentClient<I: Equatable, S: Session where S.I == I> : Client<I> {

  // All state should be stored in the session
  public var session: S

  let _connections: Observable<[Client<I>]>

  public init(session: S) {
    self.session = session

    // A list of connections is inferred by looking at
    // `connectedPeer` and `disconnectedPeer` from the underlying session.
    self._connections = returnElements(
      session.connectedPeer() >- map { (Client(iden: $0), true) },
      session.disconnectedPeer() >- map { (Client(iden: $0), false) })
    >- merge
    >- scan([]) { (connections: [Client<I>], cs) in
      let client = cs.0
      let state = cs.1
      if state {
        for c in connections { if c.iden == client.iden { return connections } }
        return connections + [client]
      } else {
        return connections.filter { $0.iden != client.iden }
      }
    }
    >- startWith([])
    >- variable

    super.init(iden: session.iden)
  }

  public func connections() -> Observable<[Client<I>]> {
    return _connections
  }

  public func connectedPeer() -> Observable<Client<I>> {
    return session.connectedPeer() >- map { Client(iden: $0) }
  }

  public func disconnectedPeer() -> Observable<Client<I>> {
    return session.disconnectedPeer() >- map { Client(iden: $0) }
  }

  // Advertising and connecting

  public func incomingConnections() -> Observable<(Client<I>, (Bool) -> ())> {
    return session.incomingConnections() >- map { (Client(iden: $0, meta: $1), $2) }
  }

  public func nearbyPeers() -> Observable<[Client<I>]> {
    return session.nearbyPeers() >- map { $0.map { Client(iden: $0, meta: $1) } }
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

  public func connect(peer: Client<I>, meta: AnyObject? = nil, timeout: NSTimeInterval = 12) {
    return session.connect(peer.iden, meta: meta, timeout: timeout)
  }

  public func disconnect() {
    return session.disconnect()
  }

  public func connectionErrors() -> Observable<NSError> {
    return session.connectionErrors()
  }

  // Sending Data

  public func send
  (other: Client<I>,
   _ data: NSData,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    return session.send(other.iden, data, mode)
  }

  public func send
  (other: Client<I>,
   _ string: String,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    return send(other, string.dataUsingEncoding(NSUTF8StringEncoding)!, mode)
  }

  public func send
  (other: Client<I>,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    return session.send(other.iden, name: name, url: url, mode)
  }

  // Receiving data

  public func receive() -> Observable<(Client<I>, NSData)> {
    return session.receive() >- map { (Client(iden: $0), $1) }
  }

  public func receive() -> Observable<(Client<I>, String)> {
    return session.receive()
    >- map { (Client(iden: $0), NSString(data: $1, encoding: NSUTF8StringEncoding)) }
    >- filter { $1 != nil }
    >- map { ($0, String($1!)) }
  }

  public func receive() -> Observable<(Client<I>, String, ResourceState)> {
    return session.receive() >- map { (Client(iden: $0), $1, $2) }
  }

  public func receive() -> Observable<(Client<I>, String, NSURL)> {
    return session.receive()
    >- filter { $2.fromFinished() != nil }
    >- map { (Client(iden: $0), $1, $2.fromFinished()!) }
  }

}
