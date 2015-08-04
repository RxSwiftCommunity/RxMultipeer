import Foundation
import RxSwift
import MultipeerConnectivity

public class MockSession : Session {

  // Store all available sessions in a global
  static public var sessions: [MockSession] = []
  static public let advertisingSessions: Variable<[MockSession]> = Variable([])

  static public func digestAdvertisingSessions() {
    advertisingSessions.next(sessions.filter { $0.isAdvertising })
  }

  static public func findForClient(client: Client) -> MockSession? {
    return filter(sessions, { o in return o.iden.isIdenticalTo(client.iden) }).first
  }

  static public func reset() {
    self.sessions = []
  }

  let _iden: MockIden
  public var iden: ClientIden { return _iden }

  public init(name: String) {
    self._iden = MockIden(name)
    MockSession.sessions.append(self)
  }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  var _connections: [MockSession] = []
  public var connections: [ClientIden] {
    return _connections.map { $0.iden }
  }

  var isAdvertising = false {
    didSet { MockSession.digestAdvertisingSessions() }
  }

  var isBrowsing = false

  let connectRequests: PublishSubject<(Client, (Bool) -> ())> = PublishSubject()

  public func nearbyPeers() -> Observable<[Client]> {
    return MockSession.advertisingSessions
           >- filter { _ in self.isBrowsing == true }
           >- map { $0.map { Client(iden: $0.iden) } }
  }

  public func startBrowsing() {
    self.isBrowsing = true
  }

  public func stopBrowsing() {
    self.isBrowsing = false
  }

  public func incomingConnections() -> Observable<(Client, (Bool) -> ())> {
    return connectRequests
  }

  public func startAdvertising() {
    self.isAdvertising = true
  }

  public func stopAdvertising() {
    self.isAdvertising = false
  }

  public func connect(peer: Client) -> Observable<Bool> {
    let otherm = filter(MockSession.sessions, { return $0.iden == peer.iden }).first
    if let other = otherm {
      if other.isAdvertising {
        return create { observer in
          sendNext(
            other.connectRequests,
            (Client(iden: self.iden),
             { [weak self] (response: Bool) in
               if !response {
                 sendNext(observer, false)
                 sendCompleted(observer)
                 return
               }

               if let this = self {
                 this._connections.append(other)
                 other._connections.append(this)
                 sendNext(observer, true)
               } else {
                 sendNext(observer, false)
               }

               sendCompleted(observer)
             }) as (Client, (Bool) -> ()))
          return AnonymousDisposable {}
        }
      }
    }

    return just(false)
  }

  public func disconnect() -> Observable<Void> {
    self._connections = []
    for session in MockSession.sessions {
      session._connections = session._connections.filter { !$0.iden.isIdenticalTo(self.iden) }
    }
    return just(())
  }

  public func connectionErrors() -> Observable<NSError> {
    return PublishSubject()
  }

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  let receivedStrings: PublishSubject<String> = PublishSubject()
  let receivedResources: PublishSubject<(String, NSURL)> = PublishSubject()

  public func receive() -> Observable<String> {
    return receivedStrings
  }

  public func receive() -> Observable<(String, NSURL)> {
    return receivedResources
  }

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  func isConnected(other: MockSession) -> Bool {
    return filter(_connections, { $0.iden == other.iden }).first != nil
  }

  public func send
  (other: Client,
   _ string: String,
   _ mode: MCSessionSendDataMode)
  -> Observable<()> {
    return create { observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          sendError(observer, UnknownError)
        } else {
          sendNext(otherSession.receivedStrings, string)
          sendCompleted(observer)
        }
      } else {
        sendError(observer, UnknownError)
      }

      return AnonymousDisposable {}
    }
  }

  public func send
  (other: Client,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode)
  -> Observable<()> {
    return create { observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          sendError(observer, UnknownError)
        } else {
          sendNext(otherSession.receivedResources, (name, url))
          sendCompleted(observer)
        }
      } else {
        sendError(observer, UnknownError)
      }

      return AnonymousDisposable {}
    }
  }

}

public class MockIden : ClientIden {

  public let string: String

  public init(_ string: String) {
    self.string = string
  }

  public func isIdenticalTo(other: ClientIden) -> Bool {
    if let o = other as? MockIden {
      return o.string == string
    }
    return false
  }

}
