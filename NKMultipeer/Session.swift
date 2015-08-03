import RxSwift

public protocol Session {

  var iden: ClientIden
  var connections: [ClientIden]

  func advertise() -> Observable<(Client, (Bool) -> ())>
  func browse() -> Observable<[Client]>
  func connect(peer: Client) -> Observable<Bool>
  func disconnect() -> Observable<Void>

  func send
  (other: Client,
   _ string: String,
   _ mode: MCSessionDataMode)
  -> Observable<()>

  func receive() -> Observable<String>

  // NSURL's are optional because not all adapters
  // will necessarily support this.

  optional func send
  (other: Client,
   name: String,
   url: NSURL,
   _ mode: MCSessionDataMode)
  -> Observable<()>

  optional func receive() -> Observable<(String, NSURL)>

}
