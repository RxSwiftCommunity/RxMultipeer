// Our goal is to create an abstraction over multipeer
// connectivity that can be tested.
public class Client {
  let iden: ClientIden
  public func sendData(data: NSData, mode: MCSessionDataMode)
  public func sendResourceAtURL(url: NSURL, withName name: String)

  public init(iden: ClientIden) {
    self.iden = iden
  }
}

public class CurrentClient : Client {
  public var session: Session
  public func disconnect() {}
  public func connectPeer(peer: Client) {}
  public func advertise() {}
  public func browse() {}
}

public protocol Session {

}

public protocol ClientIden : Equatable {
}
