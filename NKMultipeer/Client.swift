
import MultipeerConnectivity
import Foundation
import RxSwift

// It will work with any underlying object as long as they conform to the
// `Session` protocol.
public class Client {

  public var iden: ClientIden

  public init(iden: ClientIden) {
    self.iden = iden
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

  public func advertise() -> Observable<(Client, (Bool) -> ())> {
    return session.advertise()
  }

  public func browse() -> Observable<[Client]> {
    return session.browse()
  }

  public func connect(peer: Client) -> Observable<Bool> {
    return session.connect(peer)
  }

  public func disconnect() -> Observable<Void> {
    return session.disconnect()
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
