
import MultipeerConnectivity
import Foundation
import RxSwift

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

  public var connections: [Client] {
    return session.connections.map { Client(iden: $0) }
  }

  public init(session: Session) {
    self.session = session
    super.init(iden: session.iden)
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

  public func connect(peer: Client, meta: AnyObject? = nil, timeout: NSTimeInterval = 12) -> Observable<Bool> {
    return session.connect(peer, meta: meta, timeout: timeout)
  }

  public func disconnect() -> Observable<Void> {
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
