import Foundation
import RxSwift
import MultipeerConnectivity

// The protocol that adapters must adhere to.
// We want a concise common interface for p2p related operations.
public protocol Session {

  var iden: ClientIden { get }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  func connectedPeer() -> Observable<Client>
  func disconnectedPeer() -> Observable<Client>
  func incomingConnections() -> Observable<(Client, (Bool) -> ())>
  func nearbyPeers() -> Observable<[Client]>
  func startAdvertising()
  func stopAdvertising()
  func startBrowsing()
  func stopBrowsing()
  func connect(peer: Client, meta: AnyObject?, timeout: NSTimeInterval)
  func disconnect()
  func connectionErrors() -> Observable<NSError>

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  func receive() -> Observable<(Client, NSData)>
  func receive() -> Observable<(Client, String, ResourceState)>

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  func send
  (other: Client,
   _ data: NSData,
   _ mode: MCSessionSendDataMode)
  -> Observable<()>

  func send
  (other: Client,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode)
  -> Observable<()>

}
