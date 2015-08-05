# A testable abstraction over multipeer connectivity

Using the adapter pattern, we can test multipeer code with heavy mocking. In effect, we are trying to isolate all the
untestable bits of `MultipeerConnectivity` into one library.

This library also gives you the flexibility to swap out the underlying mechanics of p2p with some other protocol such as
websockets. At the moment it only comes with support for Apple's MultipeerConnectivity, however you can easily write
your own adapters for different protocols.

Please note that NKMultipeer makes heavy use of [RxSwift][RxSwift] which you should read up on if unfamiliar with Rx\* libraries. In this library, **everything is a stream**.

## Installation

```
use_frameworks!
pod "NKMultipeer"
```

## Example code

_For a working example check out the `NKMultipeer Example` folder._

### Usage

##### Imports:

```swift
import RxSwift
import NKMultipeer
```

##### Setting up the client:

```swift
// You'll need to define custom flags under `Build Settings -> Swift Compiler -> Custom Flags`
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
```

##### Browse for and connect to peers:

```swift
client.startBrowsing()
client.nearbyPeers()
// Here we are just flattening the stream
>- map { (clients: [Clients<I>]) -> Observable<Client<I>> in from(clients) }
>- merge
>- subscribeNext { (c: Client<I>) in
  // Can conditionally connect to client here
  client.connect(c)
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
```

##### Receiving messages:


```swift
client.receive()
>- subscribeNext { (o: Client<I>, s: String) in
  println("got message \(s), from client \(o)")
}
>- disposeBag.addDisposable
```

##### Support for sending/receiving

* `String`: Yes, it's serialized into `NSData` internally
* `NSData`: Yes
* `NSURL`: Yes
* `NSOutputStream` / `NSInputStream`: Not yet

### Testing

When testing, use preprocesser macros to ensure that your code uses a `MockSession` instance instead of
`MultipeerConnectivitySession`.

Then it's as simple as creating other `CurrentClient(session: MockSession(name: "other"))` instances in order to mock
nearby connectable devices. For example, if your app is running in a testing environment the following code will mock a
nearby client:

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

[rx]: http://reactivex.io/
[RxSwift]: https://github.com/kzaher/RxSwift
