import Foundation
import RxSwift
import MultipeerConnectivity

public class MockSession : Session {

  public typealias I = MockIden

  // Store all available sessions in a global
  static public var sessions: [MockSession] = []
  static public let advertisingSessions: Variable<[MockSession]> = Variable([])

  static public func digestAdvertisingSessions() {
    advertisingSessions.next(sessions.filter { $0.isAdvertising })
  }

  static public func findForClient(client: I) -> MockSession? {
    return filter(sessions, { o in return o.iden == client }).first
  }

  static public func reset() {
    self.sessions = []
  }

  let _iden: I
  public var iden: I { return _iden }

  public init(name: String) {
    self._iden = I(name)
    MockSession.sessions.append(self)
  }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  var _connections: [MockSession] = []
  var connections: [I] {
    return _connections.map { $0.iden }
  }

  var isAdvertising = false {
    didSet { MockSession.digestAdvertisingSessions() }
  }

  var isBrowsing = false

  let connectRequests: PublishSubject<(I, (Bool) -> ())> = PublishSubject()

  let rx_connectedPeer: PublishSubject<I> = PublishSubject()

  public func connectedPeer() -> Observable<I> {
    return rx_connectedPeer
  }

  let rx_disconnectedPeer: PublishSubject<I> = PublishSubject()

  public func disconnectedPeer() -> Observable<I> {
    return rx_disconnectedPeer
  }

  public func nearbyPeers() -> Observable<[I]> {
    return MockSession.advertisingSessions
           >- filter { _ in self.isBrowsing == true }
           >- map { $0.map { $0.iden } }
  }

  public func startBrowsing() {
    self.isBrowsing = true
  }

  public func stopBrowsing() {
    self.isBrowsing = false
  }

  public func incomingConnections() -> Observable<(I, (Bool) -> ())> {
    return connectRequests
  }

  public func startAdvertising() {
    self.isAdvertising = true
  }

  public func stopAdvertising() {
    self.isAdvertising = false
  }

  public func connect(peer: I, meta: AnyObject? = nil, timeout: NSTimeInterval = 12) {
    let otherm = filter(MockSession.sessions, { return $0.iden == peer }).first
    if let other = otherm {
      if other.isAdvertising {
        sendNext(
          other.connectRequests,
          (self.iden,
           { [weak self] (response: Bool) in
             if !response { return }
             if let this = self {
               this._connections.append(other)
               other._connections.append(this)
               sendNext(this.rx_connectedPeer, other.iden)
               sendNext(other.rx_connectedPeer, this.iden)
             }
           }) as (I, (Bool) -> ()))
      }
    }
  }

  public func disconnect() {
    self._connections = []
    for session in MockSession.sessions {
      for c in session._connections {
        if c.iden == self.iden {
          sendNext(session.rx_disconnectedPeer, c.iden)
        }
      }
      session._connections = session._connections.filter { $0.iden != self.iden }
    }
  }

  public func connectionErrors() -> Observable<NSError> {
    return PublishSubject()
  }

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  let receivedData: PublishSubject<(I, NSData)> = PublishSubject()
  let receivedResources: PublishSubject<(I, String, ResourceState)> = PublishSubject()

  public func receive() -> Observable<(I, NSData)> {
    return receivedData
  }

  public func receive() -> Observable<(I, String, ResourceState)> {
    return receivedResources
  }

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  func isConnected(other: MockSession) -> Bool {
    return filter(_connections, { $0.iden == other.iden }).first != nil
  }

  public func send
  (other: I,
   _ data: NSData,
   _ mode: MCSessionSendDataMode)
  -> Observable<()> {
    return create { observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          sendError(observer, UnknownError)
        } else {
          sendNext(otherSession.receivedData, (self.iden, data))
          sendCompleted(observer)
        }
      } else {
        sendError(observer, UnknownError)
      }

      return AnonymousDisposable {}
    }
  }

  public func send
  (other: I,
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
          let c = self.iden
          sendNext(otherSession.receivedResources, (c, name, .Progress(NSProgress(totalUnitCount: 1))))
          sendNext(otherSession.receivedResources, (c, name, .Finished(url)))
          sendCompleted(observer)
        }
      } else {
        sendError(observer, UnknownError)
      }

      return AnonymousDisposable {}
    }
  }

}

public class MockIden : Equatable {

  public let string: String

  public init(_ string: String) {
    self.string = string
  }

}

public func ==(left: MockIden, right: MockIden) -> Bool {
  return left.string == right.string
}
