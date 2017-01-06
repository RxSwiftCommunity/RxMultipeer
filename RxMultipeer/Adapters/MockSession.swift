import Foundation
import RxSwift
import MultipeerConnectivity

open class MockIden : Hashable {

  open let uid = ProcessInfo.processInfo.globallyUniqueString
  open let string: String
  open var displayName: String { return string }

  open var hashValue: Int {
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

open class MockSession : Session {

  public typealias I = MockIden

  // Store all available sessions in a global
  static open var sessions: [MockSession] = [] {
    didSet { digest() }
  }

  static open let advertisingSessions: Variable<[MockSession]> = Variable([])

  static open func digest() {
    advertisingSessions.value = sessions.filter { $0.isAdvertising }
  }

  static open func findForClient(_ client: I) -> MockSession? {
    return sessions.filter({ o in return o.iden == client }).first
  }

  static open func reset() {
    self.sessions = []
  }

  // Structure and initialization
  //////////////////////////////////////////////////////////////////////////

  let _iden: I
  open var iden: I { return _iden }

  let _meta: [String: String]?
  open var meta: [String: String]? { return _meta }

  open var emulateCertificationHandler = true

  public init(
    name: String,
    meta: [String: String]? = nil,
    emulateCertificationHandler emulateCert: Bool = true) {

    self._iden = I(name)
    self._meta = meta
    self.emulateCertificationHandler = emulateCert
    MockSession.sessions.append(self)
  }

  // Connection concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_connections = Variable<[Weak<MockSession>]>([])
  let rx_connectRequests = PublishSubject<(I, [String: Any]?, (Bool) -> ())>()
  let rx_certificateVerificationRequests = PublishSubject<(I, [Any]?, (Bool) -> ())>()

  open var isAdvertising = false {
    didSet { MockSession.digest() }
  }

  open var isBrowsing = false {
    didSet { MockSession.digest() }
  }

  open func connections() -> Observable<[I]> {
    return rx_connections.asObservable()
      .map { $0.filter { $0.value != nil }.map { $0.value!.iden } }
  }

  open func nearbyPeers() -> Observable<[(I, [String: String]?)]> {
    return MockSession.advertisingSessions
      .asObservable()
      .filter { _ in self.isBrowsing }
      .map { $0.map { ($0.iden, $0.meta) } }
  }

  open func incomingConnections() -> Observable<(I, [String: Any]?, (Bool) -> ())> {
    return rx_connectRequests.filter { _ in self.isAdvertising }
  }

  open func incomingCertificateVerifications() -> Observable<(I, [Any]?, (Bool) -> Void)> {
    return rx_certificateVerificationRequests.filter { _ in self.isAdvertising || self.isBrowsing }
  }

  open func startBrowsing() {
    self.isBrowsing = true
  }

  open func stopBrowsing() {
    self.isBrowsing = false
  }

  open func startAdvertising() {
    self.isAdvertising = true
  }

  open func stopAdvertising() {
    self.isAdvertising = false
  }

  open func connect(_ peer: I, context: [String: Any]? = nil, timeout: TimeInterval = 12) {
    let otherm = MockSession.sessions.filter({ return $0.iden == peer }).first
    if let other = otherm {
      // Skip if already connected
      if self.rx_connections.value.filter({ $0.value?.iden == other.iden }).count > 0 {
        return
      }

      if !other.isAdvertising {
        return
      }

      let makeConnection = { (certificateResponse: Bool) in
        if !certificateResponse {
          return
        }

        other.rx_connectRequests.on(
          .next(
            (self.iden,
             context,
             { [unowned self] (response: Bool) in
               if !response { return }
               self.rx_connections.value = self.rx_connections.value + [Weak(other)]
               other.rx_connections.value = other.rx_connections.value + [Weak(self)]
             }) as (I, [String: Any]?, (Bool) -> ())))
      }

      emulateCertificationHandler ?
        other.rx_certificateVerificationRequests.on(.next(self.iden, nil, makeConnection)) :
        makeConnection(true);
    }
  }

  open func disconnect() {
    self.rx_connections.value = []
    MockSession.sessions = MockSession.sessions.filter { $0.iden != self.iden }
    for session in MockSession.sessions {
      session.rx_connections.value = session.rx_connections.value.filter {
        $0.value?.iden != self.iden
      }
    }
  }

  open func connectionErrors() -> Observable<Error> {
    return PublishSubject()
  }

  // Data reception concerns
  //////////////////////////////////////////////////////////////////////////

  let rx_receivedData = PublishSubject<(I, Data)>()
  let rx_receivedResources = PublishSubject<(I, String, ResourceState)>()
  let rx_receivedStreamData = PublishSubject<(I, String, [UInt8])>()

  open func receive() -> Observable<(I, Data)> {
    return rx_receivedData
  }

  open func receive() -> Observable<(I, String, ResourceState)> {
    return rx_receivedResources
  }

  open func receive(fromPeer other: I,
                    streamName: String,
                    runLoop _: RunLoop = RunLoop.main,
                    maxLength: Int = 512)
    -> Observable<[UInt8]> {
    return rx_receivedStreamData
      .filter { (c, n, d) in c == other && n == streamName }
      .map { $2 }
      // need to convert to max `maxLength` sizes
      .map({ data in
        Observable.from(stride(from: 0, to: data.count, by: maxLength)
        .map({ Array(data[$0..<$0.advanced(by: min(maxLength, data.count - $0))]) }))
      })
      .concat()
  }

  // Data delivery concerns
  //////////////////////////////////////////////////////////////////////////

  func isConnected(_ other: MockSession) -> Bool {
    return rx_connections.value.filter({ $0.value?.iden == other.iden }).first != nil
  }

  open func send(toPeer other: I,
                 data: Data,
                 mode: MCSessionSendDataMode)
    -> Observable<()> {
    return Observable.create { [unowned self] observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          observer.on(.error(RxMultipeerError.connectionError))
        } else {
          otherSession.rx_receivedData.on(.next((self.iden, data)))
          observer.on(.next(()))
          observer.on(.completed)
        }
      } else {
        observer.on(.error(RxMultipeerError.connectionError))
      }

      return Disposables.create {}
    }
  }

  open func send
    (toPeer other: I,
     name: String,
     resource url: URL,
     mode: MCSessionSendDataMode)
    -> Observable<(Progress)> {
    return Observable.create { [unowned self] observer in
      if let otherSession = MockSession.findForClient(other) {
        // Can't send if not connected
        if !self.isConnected(otherSession) {
          observer.on(.error(RxMultipeerError.connectionError))
        } else {
          let c = self.iden
          otherSession.rx_receivedResources.on(.next(c, name, .progress(Progress(totalUnitCount: 1))))
          otherSession.rx_receivedResources.on(.next(c, name, .finished(url)))
          let completed = Progress(totalUnitCount: 1)
          completed.completedUnitCount = 1
          observer.on(.next(completed))
          observer.on(.completed)
        }
      } else {
        observer.on(.error(RxMultipeerError.connectionError))
      }

      return Disposables.create {}
    }
  }

  open func send
  (toPeer other: I,
   streamName name: String,
   runLoop: RunLoop = RunLoop.main)
   -> Observable<([UInt8]) -> Void> {

    return Observable.create { [unowned self] observer in

      var handler: ([UInt8]) -> Void = { _ in }

      if let otherSession = MockSession.findForClient(other) {
        handler = { d in
          otherSession.rx_receivedStreamData.on(.next(self.iden, name, d))
          observer.on(.next(handler))
        }

        if self.isConnected(otherSession) {
          observer.on(.next(handler))
        } else {
          observer.on(.error(RxMultipeerError.connectionError))
        }
      } else {
        observer.on(.error(RxMultipeerError.connectionError))
      }

      return Disposables.create {
        handler = { _ in }
      }

    }
  }

}
