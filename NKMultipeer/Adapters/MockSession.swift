import Foundation
import RxSwift
import MultipeerConnectivity

public class MockIden : Hashable {

  public let uid = NSProcessInfo.processInfo().globallyUniqueString
  public let string: String
  public var displayName: String { return string }

  public var hashValue: Int {
    return uid.hashValue
  }

  public init(_ string: String) {
    self.string = string
  }

  convenience public init(displayName: String) {
    self.init(displayName)
  }

}

public func ==(left: MockIden, right: MockIden) -> Bool {
  return left.uid == right.uid
}

public class MockSession : Session {

  public typealias I = MockIden

  // Store all available sessions in a global
  static public var sessions: [MockSession] = [] {
    didSet { digest() }
  }

  static public let advertisingSessions: Variable<[MockSession]> = Variable([])

  static public func digest() {
    advertisingSessions.value = sessions.filter { $0.isAdvertising }
  }

  static public func findForClient(client: I) -> MockSession? {
    return sessions.filter({ o in return o.iden == client }).first
  }

  static public func reset() {
    self.sessions = []
  }

  // Structure and initialization
  //////////////////////////////////////////////////////////////////////////

  let _iden: I
  public var iden: I { return _iden }

  let _meta: [String: String]?
  public var meta: [String: String]? { return _meta }

  public init(name: String, meta: [String: String]? = nil) {
    self._iden = I(name)
    self._meta = meta
    MockSession.sessions.append(self)
  }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_connections = Variable<[Weak<MockSession>]>([])
  let rx_connectRequests = PublishSubject<(I, [String: AnyObject]?, (Bool) -> ())>()

  var isAdvertising = false {
    didSet { MockSession.digest() }
  }

  var isBrowsing = false {
    didSet { MockSession.digest() }
  }

  public func connections() -> Observable<[I]> {
    return rx_connections.asObservable()
      .map { $0.filter { $0.value != nil }.map { $0.value!.iden } }
  }

  public func nearbyPeers() -> Observable<[(I, [String: String]?)]> {
    return MockSession.advertisingSessions
      .asObservable()
      .filter { _ in self.isBrowsing }
      .map { $0.map { ($0.iden, $0.meta) } }
  }

  public func incomingConnections() -> Observable<(I, [String: AnyObject]?, (Bool) -> ())> {
    return rx_connectRequests.filter { _ in self.isAdvertising }
  }

  public func startBrowsing() {
    self.isBrowsing = true
  }

  public func stopBrowsing() {
    self.isBrowsing = false
  }

  public func startAdvertising() {
    self.isAdvertising = true
  }

  public func stopAdvertising() {
    self.isAdvertising = false
  }

  public func connect(peer: I, context: [String: AnyObject]? = nil, timeout: NSTimeInterval = 12) {
    let otherm = MockSession.sessions.filter({ return $0.iden == peer }).first
    if let other = otherm {
      // Skip if already connected
      if self.rx_connections.value.filter({ $0.value?.iden == other.iden }).count > 0 {
        return
      }

      if other.isAdvertising {
        other.rx_connectRequests.on(.Next(
          (self.iden,
            context,
            { [unowned self] (response: Bool) in
              if !response { return }
              self.rx_connections.value = self.rx_connections.value + [Weak(other)]
              other.rx_connections.value = other.rx_connections.value + [Weak(self)]
            }) as (I, [String: AnyObject]?, (Bool) -> ())))
      }
    }
  }

  public func disconnect() {
    self.rx_connections.value = []
    MockSession.sessions = MockSession.sessions.filter { $0.iden != self.iden }
    for session in MockSession.sessions {
      session.rx_connections.value = session.rx_connections.value.filter {
        $0.value?.iden != self.iden
      }
    }
  }

  public func connectionErrors() -> Observable<NSError> {
    return PublishSubject()
  }

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_receivedData = PublishSubject<(I, NSData)>()
  let rx_receivedResources = PublishSubject<(I, String, ResourceState)>()
  let rx_receivedStreamData = PublishSubject<(I, String, [UInt8])>()

  public func receive() -> Observable<(I, NSData)> {
    return rx_receivedData
  }

  public func receive() -> Observable<(I, String, ResourceState)> {
    return rx_receivedResources
  }

  public func receive(other: I,
                      streamName: String,
                      runLoop _: NSRunLoop = NSRunLoop.mainRunLoop(),
                      maxLength: Int = 512)
                      -> Observable<[UInt8]> {
    return rx_receivedStreamData
      .filter { (c, n, d) in c == other && n == streamName }
      .map { $2 }
      // need to convert to max `maxLength` sizes
      .map({ data in
             0.stride(to: data.count, by: maxLength)
               .map({ Array(data[$0..<$0.advancedBy(maxLength, limit: data.count)]) })
               .toObservable()
           })
           .concat()
  }

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  func isConnected(other: MockSession) -> Bool {
    return rx_connections.value.filter({ $0.value?.iden == other.iden }).first != nil
  }

  public func send
  (other: I,
   _ data: NSData,
   _ mode: MCSessionSendDataMode)
  -> Observable<()> {
    return Observable.create { [unowned self] observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          observer.on(.Error(NKMultipeerError.ConnectionError))
        } else {
          otherSession.rx_receivedData.on(.Next((self.iden, data)))
          observer.on(.Next(()))
          observer.on(.Completed)
        }
      } else {
        observer.on(.Error(NKMultipeerError.ConnectionError))
      }

      return AnonymousDisposable {}
    }
  }

  public func send
  (other: I,
   name: String,
   url: NSURL,
   _ mode: MCSessionSendDataMode)
  -> Observable<(NSProgress)> {
    return Observable.create { [unowned self] observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          observer.on(.Error(NKMultipeerError.ConnectionError))
        } else {
          let c = self.iden
          otherSession.rx_receivedResources.on(.Next(c, name, .Progress(NSProgress(totalUnitCount: 1))))
          otherSession.rx_receivedResources.on(.Next(c, name, .Finished(url)))
          let completed = NSProgress(totalUnitCount: 1)
          completed.completedUnitCount = 1
          observer.on(.Next(completed))
          observer.on(.Completed)
        }
      } else {
        observer.on(.Error(NKMultipeerError.ConnectionError))
      }

      return AnonymousDisposable {}
    }
  }

  public func send
  (other: I,
   streamName name: String,
   runLoop: NSRunLoop = NSRunLoop.mainRunLoop())
   -> Observable<([UInt8]) -> Void> {

    return Observable.create { [unowned self] observer in

      var handler: ([UInt8]) -> Void = { _ in }

      if let otherSession = MockSession.findForClient(other) {
        handler = { d in
          otherSession.rx_receivedStreamData.on(.Next(self.iden, name, d))
          observer.on(.Next(handler))
        }

        if self.isConnected(otherSession) {
          observer.on(.Next(handler))
        } else {
          observer.on(.Error(NKMultipeerError.ConnectionError))
        }
      } else {
        observer.on(.Error(NKMultipeerError.ConnectionError))
      }

      return AnonymousDisposable {
        handler = { _ in }
      }

    }
  }

}
