# A testable abstraction over multipeer connectivity

Using the adapter pattern, we can test multipeer code with heavy mocking. In effect, we are trying to isolate all the
untestable bits of `MultipeerConnectivity` into one library.

This library also gives you the flexibility to swap out the underlying mechanics of p2p with some other protocol such as
websockets. At the moment it only comes with support for Apple's MultipeerConnectivity, however you can easily write
your own adapters for different protocols.

Please note that NKMultipeer makes heavy use of [RxSwift](https://github.com/kzaher/RxSwift) which you should read up on
if unfamiliar with Rx* libraries.

## Installation

```
use_frameworks!
pod "NKMultipeer"
```

## Example code

### @TODO : Testing

### @TODO : Usage
