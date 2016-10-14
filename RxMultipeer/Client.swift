import Foundation
import MultipeerConnectivity
import RxSwift

/// A client represents a peer in an arbitrary network.
/// It is a wrapper around `IdenType` which is defined by the
/// underlying session adapter in use.
///
/// It's only function is to be able to correctly identify the
/// client it represents within the given adapter's network.
open class Client<I> where I: Hashable {

  public typealias IdenType = I

  /// The identifier specified by the given `Session`.
  /// Anything `Hashable` is a valid candidate.
  open let iden: IdenType

  public init(iden: IdenType) {
    self.iden = iden
  }
}

/// The client that represents the host device. Like the `Client`, it identifies itself.
/// On top of that, it provides an interface for discovering and interacting with other clients.
open class CurrentClient<I: Hashable, S: Session> : Client<I> where S.I == I {

  /// The `Session` coupled with this client, and space in which this client
  /// will operate. Every `CurrentClient` has a one-to-one relationship with
  /// a `Sesssion`.
  open let session: S

  var disposeBag = DisposeBag()

  public init(session: S) {
    self.session = session
    super.init(iden: session.iden)
  }

  /// - Returns: An `Observable` of clients currently connected in the session
  open func connections() -> Observable<[Client<I>]> {
    return session.connections()
      .map { $0.map { Client(iden: $0) } }
  }

  /// - Returns: An `Observable` of newly connected clients, as they become connected
  open func connectedPeer() -> Observable<Client<I>> {
    return session.connections()
      .scan(([], [])) { (previousSet: ([I], [I]), current: [I]) in (previousSet.1, current) }
      .map { (previous, current) in Array(Set(current).subtracting(previous)) }
      .map { Observable.from($0.map(Client<I>.init)) }
      .concat()
  }

  /// - Returns: An `Observable` of newly disconnected clients
  open func disconnectedPeer() -> Observable<Client<I>> {
    return session.connections()
      .scan(([], [])) { (previousSet: ([I], [I]), current: [I]) in (previousSet.1, current) }
      .map { (previous, current) in Array(Set(previous).subtracting(current)) }
      .map { Observable.from($0.map(Client<I>.init)) }
      .concat()
  }

  /// - Returns: An `Observable` of incoming connections, as a tuple of:
  ///   - Sender's `Client`
  ///   - Context dictionary, passed in to `connect(peer:context:timeout)`
  ///   - The response handler, calling it with `true` will attempt to establish the connection
  open func incomingConnections() -> Observable<(Client<I>, [String: Any]?, (Bool) -> ())> {
    return session.incomingConnections()
    .map { (iden, context, respond) in
      (Client(iden: iden), context, respond)
    }
  }

  /// - Returns: An `Observable` of clients that are nearby, as a tuple of:
  ///   - The nearby peer's `Client`
  ///   - The nearby peer's `metaData`
  open func nearbyPeers() -> Observable<[(Client<I>, [String: String]?)]> {
    return session.nearbyPeers().map { $0.map { (Client(iden: $0), $1) } }
  }

  /// Start advertising using the underlying `session`
  open func startAdvertising() {
    session.startAdvertising()
  }

  /// Stop advertising using the underlying `session`
  open func stopAdvertising() {
    session.stopAdvertising()
  }

  /// Start browsing using the underlying `session`
  open func startBrowsing() {
    session.startBrowsing()
  }

  /// Stop browsing using the underlying `session`
  open func stopBrowsing() {
    session.stopBrowsing()
  }

  /// Invite the given peer to connect.
  /// - Parameters:
  ///   - peer: The recipient peer
  ///   - context: The context
  ///   - timeout: The amount of time to wait for a response before giving up
  open func connect(_ peer: Client<I>, context: [String: Any]? = nil, timeout: TimeInterval = 12) {
    return session.connect(peer.iden, context: context, timeout: timeout)
  }

  /// Disconnect using the underlying `session`.
  /// This behavior of this depends on the implementation of the `Session` adapter.
  open func disconnect() {
    return session.disconnect()
  }

  /// - Returns: An `Observable` of errors that occur during client connection time.
  open func connectionErrors() -> Observable<Error> {
    return session.connectionErrors()
  }

  // Sending Data

  /// Send `Data` to the given peer.
  ///
  /// - Returns: An `Observable` that calls `Event.Completed` once the transfer is complete.
  ///   The semantics of _completed_ depends on the `mode` parameter.
  open func send
  (_ other: Client<I>,
   _ data: Data,
   _ mode: MCSessionSendDataMode = .reliable)
  -> Observable<()> {
    return session.send(other.iden, data, mode)
  }

  /// Send `String` to the given peer.
  ///
  /// - Returns: An `Observable` that calls `Event.Completed` once the transfer is complete.
  ///   The semantics of _completed_ depends on the `mode` parameter.
  open func send
  (_ other: Client<I>,
   _ string: String,
   _ mode: MCSessionSendDataMode = .reliable)
  -> Observable<()> {
    return send(other, string.data(using: String.Encoding.utf8)!, mode)
  }

  /// Send json in the form of `[String: Any]` to the given peer.
  ///
  /// - Parameter json: This is serialized with `NSJSONSerialization`. An `Event.Error` is emitted from the
  ///   `Observable` if a serialization error occurs.
  /// - Returns: An `Observable` that calls `Event.Completed` once the transfer is complete.
  ///   The semantics of _completed_ depends on the `mode` parameter.
  open func send
  (_ other: Client<I>,
   _ json: [String: Any],
   _ mode: MCSessionSendDataMode = .reliable)
  -> Observable<()> {
    do {
      let data = try JSONSerialization.data(
        withJSONObject: json, options: JSONSerialization.WritingOptions())
      return send(other, data, mode)
    } catch let error as NSError {
      return Observable.error(error)
    }
  }

  /// Send a file-system resource to the given peer.
  ///
  /// - Parameter url: The URL to the underlying file that needs to be sent.
  /// - Returns: An `Observable` that represents the `NSProgress` of the file transfer.
  ///   It emits `Event.Completed` once the transfer is complete.
  ///   The semantics of _completed_ depends on the `mode` parameter.
  open func send
  (_ other: Client<I>,
   name: String,
   url: URL,
   _ mode: MCSessionSendDataMode = .reliable)
  -> Observable<Progress> {
    return session.send(other.iden, name: name, url: url, mode)
  }

  /// Open a pipe to the given peer, allowing you send them bits.
  ///
  /// - Parameters:
  ///   - streamName: The name of the stream that is passed to the recipient
  ///   - runLoop: The runloop that is respondsible for fetching more source data when necessary
  /// - Returns: An `Observable` that emits requests for more data, in the form of a callback.
  open func send(_ other: Client<I>,
                   streamName: String,
                   runLoop: RunLoop = RunLoop.main)
                   -> Observable<([UInt8]) -> Void> {
    return session.send(other.iden,
                        streamName: streamName,
                        runLoop: runLoop)
  }

  // Receiving data

  /// Receive `Data` streams from the `session`.
  ///
  /// - Returns: An `Observable` of:
  ///   - Sender
  ///   - Received data
  open func receive() -> Observable<(Client<I>, Data)> {
    return session.receive().map { (Client(iden: $0), $1) }
  }

  /// Receive json streams from the `session`.
  ///
  /// - Returns: An `Observable` of:
  ///   - Sender
  ///   - Received json
  open func receive() -> Observable<(Client<I>, [String: Any])> {
    return (receive() as Observable<(Client<I>, Data)>)
      .map { (client: Client<I>, data: Data) -> Observable<(Client<I>, [String: Any])> in
      do {
        let json = try JSONSerialization.jsonObject(
          with: data, options: JSONSerialization.ReadingOptions())
        if let j = json as? [String: Any] {
          return Observable.just((client, j))
        }
        return Observable.never()
      } catch let error {
        return Observable.error(error)
      }
    }
    .merge()
  }

  /// Receive `String` streams from the `session`.
  ///
  /// - Returns: An `Observable` of:
  ///   - Sender
  ///   - Message
  open func receive() -> Observable<(Client<I>, String)> {
    return session.receive()
    .map { (Client(iden: $0), NSString(data: $1, encoding: String.Encoding.utf8.rawValue)) }
    .filter { $1 != nil }
    .map { ($0, String($1!)) }
  }

  /// Receive a file from the `session`. `ResourceState` encapsulates the progress of
  /// the transfer.
  ///
  /// - Seealso: `receive() -> Observable<(Client<I>, String, NSURL)>`
  /// - Returns: An `Observable` of:
  ///   - Sender
  ///   - File name
  ///   - The `ResourceState` of the resource
  open func receive() -> Observable<(Client<I>, String, ResourceState)> {
    return session.receive().map { (Client(iden: $0), $1, $2) }
  }

  /// Receive a file from the `session`. Ignore the progress, a single `Event.Next`
  /// will be emitted for when the transfer is complete.
  ///
  /// - Seealso: `receive() -> Observable<(Client<I>, String, ResourceState)>`
  /// - Returns: An `Observable` of:
  ///   - Sender
  ///   - File name
  ///   - The `NSURL` of the file's temporary location
  open func receive() -> Observable<(Client<I>, String, URL)> {
    return session.receive()
    .filter { $2.fromFinished() != nil }
    .map { (Client(iden: $0), $1, $2.fromFinished()!) }
  }

  /// Receive a specific bitstream from a specific sender.
  ///
  /// - Parameters:
  ///   - streamName: The stream name to accept data from
  ///   - runLoop: The run loop on which to queue newly received data
  ///   - maxLength: The maximum buffer size before flush
  ///
  /// - Returns: An `Observable` of bytes as they are received.
  /// - Remark: Even though most of the time data is received in the exact
  ///   same buffer sizes/segments as they were sent, this is not guaranteed.
  open func receive(_ other: Client<I>,
                      streamName: String,
                      runLoop: RunLoop = RunLoop.main,
                      maxLength: Int = 512)
                      -> Observable<[UInt8]> {
    return session.receive(other.iden,
                           streamName: streamName,
                           runLoop: runLoop,
                           maxLength: maxLength)
  }

  deinit {
    self.disconnect()
  }

}
