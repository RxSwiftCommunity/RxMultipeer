# A testable RxSwift wrapper around MultipeerConnectivity

RxMultipeer is a [RxSwift][RxSwift] wrapper for MultipeerConnectivity.

Using the adapter pattern, we can test multipeer code with heavy mocking. In effect, we are trying to isolate all the
untestable bits of `MultipeerConnectivity` into one library.

This library also gives you the flexibility to swap out the underlying mechanics of p2p with some other protocol such as
websockets. At the moment it only comes with support for Apple's MultipeerConnectivity, however you can easily write
your own adapters for different protocols.

## Installation

#### Carthage

Add this to your `Cartfile`

```
github "RxSwiftCommunity/RxMultipeer" ~> 3.0
```

## Example code

_For a working example check out the `RxMultipeer Example` folder._

#### Advertise and accept nearby peers

```swift
import RxSwift
import RxCocoa
import RxMultipeer

let disposeBag: DisposeBag
let acceptButton: UIButton
let client: CurrentClient<MCPeerID>

client.startAdvertising()
let connectionRequests = client.incomingConnections().shareReplay(1)

acceptButton.rx_tap
  .withLatestFrom(connectionRequests)
  .subscribe(onNext: { (peer, context, respond) in respond(true) })
  .addDisposableTo(disposeBag)

client.incomingCertificateVerifications()
    .subscribe(onNext: { (peer, certificateChain, respond) in
      // Validate the certificateChain
      respond(true)
    })
    .addDisposableTo(disposeBag)
```

#### Browse for and connect to peers

```swift
import RxSwift
import RxMultipeer

let disposeBag: DisposeBag
let client: CurrentClient<MCPeerID>

client.startBrowsing()

let nearbyPeers = client.nearbyPeers().shareReplay(1)

// Attempt to connect to all peers
nearbyPeers
  .map { (peers: [Client<MCPeerID>]) in
    peers.map { client.connect(toPeer: $0, context: ["Hello": "there"], timeout: 12) }.zip()
  }
  .subscribe()
  .addDisposableTo(disposeBag)
```

#### Sending and receiving strings

Sending them:

```swift
import RxSwift
import RxCocoa
import RxMultipeer

let disposeBag: DisposeBag
let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>
let sendButton: UIButton

sendButton.rx_tap
  .withLatestFrom(peer)
  .map { client.send(toPeer: peer, string: "Hello!") }
  .switchLatest()
  .subscribe(onNext: { _ in print("Message sent") })
  .addDisposableTo(disposeBag)
```

And receiving them:

```swift
import RxSwift
import RxMultipeer

let disposeBag: DisposeBag
let client: CurrentClient<MCPeerID>

client.receive()
.subscribe(onNext: { (peer: Client<MCPeerID>, message: String) in
  print("got message \(message), from peer \(peer)")
})
.addDisposableTo(disposeBag)
```

#### Establishing a data stream

RxSwift makes sending streaming data to a persistent connection with another
peer very intuitive.

The sender:

```swift
import RxSwift
import RxMultipeer

let disposeBag: DisposeBag
let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>
let queuedMessages: Observable<[UInt8]>

let pipe = peer.map { client.send(toPeer: peer, streamName: "data.stream") }
pipe.withLatestFrom(queuedMessages) { $0 }
  .subscribe(onNext: { (sender, message) in sender(message) })
  .addDisposableTo(disposeBag)
```

The receiver:

```swift
import RxSwift
import RxMultipeer

let disposeBag: DisposeBag
let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>

let incomingData = client.receive(fromPeer: peer, streamName: "data.stream").shareReplay(1)
incomingData
  .subscribe(onNext: { (data) in print(data) })
  .addDisposableTo(disposeBag)
```

## Usage

#### Imports

```swift
import RxSwift
import RxMultipeer
```

#### Make a new build configuration for testing

Your project comes with `Debug` and `Release` build configurations by default, we need to make a new one called
`Testing`. [Please check here for step-by-step instructions][buildconfig].

#### Setting up the client

```swift
// See the link above,
// You'll need to define a new build configuration and give it the `TESTING` flag
let name = UIDevice.currentDevice().name
#if TESTING
typealias I = MockIden
let client = CurrentClient(session: MockSession(name: name))
#else
typealias I = MCPeerID
let client = CurrentClient(session: MultipeerConnectivitySession(
                 displayName: name,
                 serviceType: "multipeerex",
                 idenCacheKey: "com.rxmultipeer.example.mcpeerid",
                 encryptionPreference: .None))
#endif
```

## Supported transfer resource types

#### String

```swift
func send(toPeer: Client, string: String, mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, String)>
```

#### Data

```swift
func send(toPeer: Client, data: Data, mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, Data)>
```

#### JSON

```swift
func send(toPeer: Client, json: [String: Any], mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, [String: Any])>
```

#### NSURL

```swift
func send(toPeer: Client, name: String, url: NSURL, mode: MCSessionSendDataMode = .Reliable) -> Observable<NSProgress>
func receive() -> Observable<(Client, String, ResourceState)>
```

#### NSStream

```swift
func send(toPeer: Client, streamName: String, runLoop: NSRunLoop = NSRunLoop.mainRunLoop()) -> Observable<([UInt8]) -> Void>
func receive(fromPeer: Client, streamName: String, runLoop: NSRunLoop = NSRunLoop.mainRunLoop(), maxLength: Int = 512) -> Observable<[UInt8]>
```

## Testing

When testing, use preprocesser macros to ensure that your code uses a `MockSession` instance instead of
`MultipeerConnectivitySession` one. In order to achieve this you need to use preprocessor flags and swap out anywhere
that references `Client<T>` (because `T` will be different depending on whether you are testing or not.) First you will
need to [set up a new build configuration][buildconfig], and then you can use preprocessor macros like so:

```swift
let name = UIDevice.currentDevice().name
#if TESTING
typealias I = MockIden
let client = CurrentClient(session: MockSession(name: name))
#else
typealias I = MCPeerID
let client = CurrentClient(session: MultipeerConnectivitySession(
                 displayName: name,
                 serviceType: "multipeerex",
                 idenCacheKey: "com.rxmultipeer.example.mcpeerid",
                 encryptionPreference: .None))
#endif
```

Don't worry, you should only really need preprocessor macros in one centralized place, the type of your client can be
inferred by the compiler thereafter.

Mocking other nearby peers in the test environment then becomes as simple as creating other `CurrentClient(session:
MockSession(name: "other"))`. For example, if your app is running in a testing environment the following code will mock
a nearby client:

```swift
let disposeBag: DisposeBag
let otherclient = CurrentClient(session: MockSession(name: "mockedother"))

// Accept all connections
otherclient.startAdvertising()

otherclient.incomingConnections()
  .subscribeNext { (client, context, respond) in respond(true) }
  .addDisposableTo(disposeBag)

// Starting from version 3.0.0 the following handler needs to be implemented
// for this library to work:
otherclient.incomingCertificateVerifications()
  .subscribeNext { (client, certificateChain, respond) in respond(true) }
  .addDisposableTo(disposeBag)

// Respond to all messages with 'Roger'
otherclient.receive()
  .map { (client: Client<MockIden>, string: String) in otherclient.send(toPeer: client, "Roger") }
  .concat()
  .subscribeNext { _ in print("Response sent") }
  .addDisposableTo(disposeBag)
```

## Breaking changes

### Version 3.0.0

Starting from version `3.0.0`, `incomingCertificateVerifications() -> Observable<(MCPeerID, [Any]?, (Bool) -> Void)>`
was introduced. This needs to be implemented in order for mock and real
connections to work. Behaviour prior to this update can be reproduced by simply
accepting all certificates:

```
let client: CurrentClient<MCPeerID
client.incomingCertificateVerifications()
    .subscribe(onNext: { (peer, certificateChain, respond) in
      // Validate the certificateChain
      respond(true)
    })
    .addDisposableTo(disposeBag)
```

## Contributing

* Indent with 2 spaces
* Strip trailing whitespace
* Write tests
* Pull-request from feature branches.

[rx]: http://reactivex.io/
[RxSwift]: https://github.com/kzaher/RxSwift
[buildconfig]: https://github.com/nathankot/NKMultipeer/wiki/How-to-define-custom-flags-for-the-testing-environment
