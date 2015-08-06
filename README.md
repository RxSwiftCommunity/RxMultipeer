# A testable abstraction over multipeer connectivity

Using the adapter pattern, we can test multipeer code with heavy mocking. In effect, we are trying to isolate all the
untestable bits of `MultipeerConnectivity` into one library.

This library also gives you the flexibility to swap out the underlying mechanics of p2p with some other protocol such as
websockets. At the moment it only comes with support for Apple's MultipeerConnectivity, however you can easily write
your own adapters for different protocols.

Please note that NKMultipeer makes heavy use of [RxSwift][RxSwift] which you should read up on if unfamiliar with Rx\*
libraries. The mantra for this library: **everything is a stream**.

_Using Rx* is ultimately optional_ because the interface provides non-rx alternatives for every single method, however
it's strongly encouraged to try out _RxSwift_ if you're not using any other FRP libraries.

## Installation

```
use_frameworks!
pod "NKMultipeer"
```

## Example code

_For a working example check out the `NKMultipeer Example` folder._

### Usage

Examples here are _overly type annotated_ in order to give a clear idea of what's going on. For most cases, you can omit
types found in blocks or even arguments altogether for more concise-looking code.

##### Imports:

```swift
import RxSwift
import NKMultipeer
```

#### Make a new build configuration for testing:

Your project comes with `Debug` and `Release` build configurations by default, we need to make a new one called
`Testing`. [Please check here for step-by-step instructions][buildconfig].

##### Setting up the client:

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

##### Advertise and accept nearby peers:

```swift
client.startAdvertising() // Allow other clients to try and connect
client.incomingConnections()
>- subscribeNext { (c, respond) in
  // You can put response logic here
  respond(true)
}
>- disposeBag.addDisposable

// OR, Using vanilla callbacks:
client.incomingConnections() { (c, respond) in respond(true)}
```

##### Browse for and connect to peers:

```swift
client.startBrowsing()
client.nearbyPeers()
// Here we are just flattening the stream
>- map { (clients: [Client<I>]) -> Observable<Client<I>> in from(clients) }
>- merge
>- subscribeNext { (c: Client<I>) in
  // Can conditionally connect to client here
  client.connect(c)
  // You can listen to newly connected peers using
  // `client.connectedPeer()`
}

// OR, Using vanilla callbacks:
client.nearbyPeers() { (clients: [Client<I>]) in
  for c in clients {
    c.connect()
  }
}
```

##### Sending messages:

```swift
// Assume we have an observable for a peer we're interested in
let other: Observable<Client<I>> = ???

// We can store the result of the send action in a variable
let sendToOther = other
>- map { client.send(other, "Hello!") }
>- switchLatest
>- variable

// And declare we want to do something with each send result later on
sendToOther
>- subscribeCompleted { println("a message was sent") }
>- disposeBag.addDisposable

// OR, Using vanilla callbacks:
client.send(other, "Hello!") { println("message was sent") }
```

##### Receiving messages:


```swift
client.receive()
>- subscribeNext { (o: Client<I>, s: String) in
  println("got message \(s), from client \(o)")
}
>- disposeBag.addDisposable

// OR, Using vanilla callbacks:
client.receive() { (o: Client<I>, s: String) in
  println("got message \(s), from client \(o)")
}
```

##### Support for sending/receiving

* `String`: Yes, it's serialized into `NSData` internally
* `NSData`: Yes
* `NSURL`: Yes
* `NSOutputStream` / `NSInputStream`: Not yet

### Testing

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
>- subscribeNext { (client, respond) in respond(true) }
>- disposeBag.addDisposable

// Respond to all messages with 'Roger'
otherclient.receive()
>- map { (client: Client<MockIden>, string: String) in return otherclient.send(client, "Roger")}
>- concat
>- subscribeNext { _ in println("Response sent") }
>- disposeBag.addDisposable
```

### What is `DisposeBag`?? `>-`??

These are [RxSwift][RxSwift] things. `DisposeBag` is how memory management is handled in `Rx` and `>-` is the pipe
operator that applies the argument on the left to the function on the right i.e `a >- f === f(a)`.

Please read up on [ReactiveX][rx] for a general overview on reactive.

Every method in `CurrentClient` provides a non-rx alternative that accepts a callback however, so you do not need to use
Rx* when interfacing with this library.

## Contributing

* Indent with 2 spaces
* Strip trailing whitespace
* Write tests
* Pull-request from feature branches.

[rx]: http://reactivex.io/
[RxSwift]: https://github.com/kzaher/RxSwift
[buildconfig]: https://github.com/nathankot/NKMultipeer/wiki/How-to-define-custom-flags-for-the-testing-environment
