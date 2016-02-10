import Foundation
import MultipeerConnectivity
import RxSwift

public protocol ClientType {
  typealias IdenType: Equatable
  var iden: IdenType { get }
}

// It will work with any underlying object as long as they conform to the
// `Session` protocol.
public class Client<I: Equatable> : ClientType {
  public typealias IdenType = I
  public let iden: IdenType

  public init(iden: IdenType) {
    self.iden = iden
  }
}

public class CurrentClient<I: Equatable, S: Session where S.I == I> : Client<I> {

  // All state should be stored in the session
  public let session: S

  // This is only used to retain things for callback variants
  var disposeBag = DisposeBag()

  public init(session: S) {
    self.session = session
    super.init(iden: session.iden)
  }

  public func connections() -> Observable<[Client<I>]> {
    return session.connections()
      .map { $0.map { Client(iden: $0) } }
  }

  public func connectedPeer() -> Observable<Client<I>> {
    return session.connectedPeer().map { Client(iden: $0) }
  }

  public func disconnectedPeer() -> Observable<Client<I>> {
    return session.disconnectedPeer().map { Client(iden: $0) }
  }

  // Advertising and connecting

  public func incomingConnections() -> Observable<(Client<I>, [String: AnyObject]?, (Bool) -> ())> {
    return session.incomingConnections()
    .map { (iden, context, respond) in
      (Client(iden: iden), context, respond)
    }
  }

  public func nearbyPeers() -> Observable<[(Client<I>, [String: String]?)]> {
    return session.nearbyPeers().map { $0.map { (Client(iden: $0), $1) } }
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

  public func connect(peer: Client<I>, context: [String: AnyObject]? = nil, timeout: NSTimeInterval = 12) {
    return session.connect(peer.iden, context: context, timeout: timeout)
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
   _ json: [String: AnyObject],
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<()> {
    do {
      let data = try NSJSONSerialization.dataWithJSONObject(
        json, options: NSJSONWritingOptions())
      return send(other, data, mode)
    } catch let error as NSError {
      return Observable.error(error)
    }
  }

  public func send
  (other: Client<I>,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode = .Reliable)
  -> Observable<NSProgress> {
    return session.send(other.iden, name: name, url: url, mode)
  }


  // Receiving data

  public func receive() -> Observable<(Client<I>, NSData)> {
    return session.receive().map { (Client(iden: $0), $1) }
  }

  public func receive() -> Observable<(Client<I>, [String: AnyObject])> {
    return (receive() as Observable<(Client<I>, NSData)>)
      .map { (client: Client<I>, data: NSData) -> Observable<(Client<I>, [String: AnyObject])> in
      do {
        let json = try NSJSONSerialization.JSONObjectWithData(
          data, options: NSJSONReadingOptions())
        if let j = json as? [String: AnyObject] {
          return Observable.just((client, j))
        }
        return Observable.never()
      } catch let error {
        return Observable.error(error)
      }
    }
    .merge()
  }

  public func receive() -> Observable<(Client<I>, String)> {
    return session.receive()
    .map { (Client(iden: $0), NSString(data: $1, encoding: NSUTF8StringEncoding)) }
    .filter { $1 != nil }
    .map { ($0, String($1!)) }
  }

  public func receive() -> Observable<(Client<I>, String, ResourceState)> {
    return session.receive().map { (Client(iden: $0), $1, $2) }
  }

  public func receive() -> Observable<(Client<I>, String, NSURL)> {
    return session.receive()
    .filter { $2.fromFinished() != nil }
    .map { (Client(iden: $0), $1, $2.fromFinished()!) }
  }


  deinit {
    self.disconnect()
  }

}
