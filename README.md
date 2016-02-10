# A testable, Rx* wrapper around MultipeerConnectivity

Using the adapter pattern, we can test multipeer code with heavy mocking. In effect, we are trying to isolate all the
untestable bits of `MultipeerConnectivity` into one library.

This library also gives you the flexibility to swap out the underlying mechanics of p2p with some other protocol such as
websockets. At the moment it only comes with support for Apple's MultipeerConnectivity, however you can easily write
your own adapters for different protocols.

Please note that NKMultipeer makes heavy use of [RxSwift][RxSwift] which you should read up on if unfamiliar with Rx\*
libraries. The mantra for this library: **everything is a stream**.

## Installation

#### Carthage

Add this to your `Cartfile`

```
github "nathankot/NKMultipeer" ~> 1.0.0
```

#### Cocoapods

```
use_frameworks!
pod "NKMultipeer"
```

## Example code

_For a working example check out the `NKMultipeer Example` folder._

#### Advertise and accept nearby peers

```swift
import RxSwift
import RxCocoa
import NKMultipeer

let acceptButton: UIButton
let client: CurrentClient<MCPeerID>

client.startAdvertising()
let connectionRequests = client.incomingConnections().shareReplay(1)

acceptButton.rx_tap
  .withLatestFrom(connectionRequests)
  .subscribeNext { (peer, context, respond) in respond(true) }
  .addDisposableTo(disposeBag)
```

#### Browse for and connect to peers

```swift
import RxSwift
import NKMultipeer

let client: CurrentClient<MCPeerID>

client.startBrowsing()

let nearbyPeers = client.nearbyPeers().shareReplay(1)

// Attempt to connect to all peers
nearbyPeers
  .map { (peers: [Client<MCPeerID>]) in
    peers.map { client.connect($0, context: ["Hello": "there"], timeout: 12) }.zip()
  }
  .subscribe()
  .addDisposableTo(disposeBag)
```

#### Sending and receiving strings

Sending them:

```swift
import RxSwift
import RxCocoa
import NKMultipeer

let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>
let sendButton: UIButton

sendButton.rx_tap
  .withLatestFrom(peer)
  .map { client.send(peer, "Hello!") }
  .switchLatest()
  .subscribeNext { _ in print("Message sent") }
  .addDisposableTo(disposeBag)
```

And receiving them:

```swift
import RxSwift
import NKMultipeer

let client: CurrentClient<MCPeerID>

client.receive()
.subscribeNext { (peer: Client<MCPeerID>, message: String) in
  print("got message \(message), from peer \(peer)")
}
.addDisposableTo(disposeBag)
```

#### Establishing a data stream

RxSwift makes sending streaming data to a persistent connection with another
peer very intuitive.

The sender:

```swift
import RxSwift
import NKMultipeer

let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>
let queuedMessages: Observable<[UInt8]>

let pipe = peer.map { client.send(peer, streamName: "data.stream") }
pipe.withLatestFrom(queuedMessages) { $0 }
  .subscribeNext { (sender, message) in sender(message) }
  .addDisposableTo(disposeBag)
```

The receiver:

```swift
import RxSwift
import NKMultipeer

let client: CurrentClient<MCPeerID>
let peer: Observable<Client<MCPeerID>>

let incomingData = client.receive(peer, streamName: "data.stream").shareReplay(1)
incomingData.subscribeNext { (data) in print(data) }
  .addDisposableTo(disposeBag)
```

## Usage

#### Imports

```swift
import RxSwift
import NKMultipeer
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
                 encryptionPreference: .None))
#endif
```

## Supported transfer resource types

#### String

```swift
func send(other: Client, _ string: String, _ mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, String)>
```

#### NSData

```swift
func send(other: Client, _ data: NSData, _ mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, NSData)>
```

#### JSON

```swift
func send(other: Client, _ json: [String: AnyObject], _ mode: MCSessionSendDataMode = .Reliable) -> Observable<()>
func receive() -> Observable<(Client, [String: AnyObject])>
```

#### NSURL

```swift
func send(other: Client, name: String, url: NSURL, _ mode: MCSessionSendDataMode = .Reliable) -> Observable<NSProgress>
func receive() -> Observable<(Client, String, ResourceState)>
```

#### NSStream

```swift
func send(other: Client, streamName: String, runLoop: NSRunLoop = NSRunLoop.mainRunLoop()) -> Observable<([UInt8]) -> Void>
func receive() -> Observable<(Client, String, NSURL)>
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
                 encryptionPreference: .None))
#endif
```

Don't worry, you should only really need preprocessor macros in one centralized place, the type of your client can be
inferred by the compiler thereafter.

Mocking other nearby peers in the test environment then becomes as simple as creating other `CurrentClient(session:
MockSession(name: "other"))`. For example, if your app is running in a testing environment the following code will mock
a nearby client:

```swift
let otherclient = CurrentClient(session: MockSession(name: "mockedother"))

// Accept all connections
otherclient.startAdvertising()
otherclient.incomingConnections()
.subscribeNext { (client, context, respond) in respond(true) }
.addDisposableTo(disposeBag)

// Respond to all messages with 'Roger'
otherclient.receive()
.map { (client: Client<MockIden>, string: String) in return otherclient.send(client, "Roger") }
.concat()
.subscribeNext { _ in print("Response sent") }
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
