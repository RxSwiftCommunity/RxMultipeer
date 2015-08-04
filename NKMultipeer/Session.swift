import RxSwift
import MultipeerConnectivity

public protocol Session {

  var iden: ClientIden { get }
  var connections: [ClientIden] { get }

  func advertise() -> Observable<(Client, (Bool) -> ())>
  func browse() -> Observable<[Client]>
  func connect(peer: Client) -> Observable<Bool>
  func disconnect() -> Observable<Void>

  func send
  (other: Client,
   _ string: String,
   _ mode: MCSessionSendDataMode)
  -> Observable<()>

  func receive() -> Observable<String>

  func send
  (other: Client,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode)
  -> Observable<()>

  func receive() -> Observable<(String, NSURL)>

}
