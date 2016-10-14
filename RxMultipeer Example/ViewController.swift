//
//  ViewController.swift
//  RxMultipeer Example
//
//  Created by Nathan Kot on 5/08/15.
//  Copyright (c) 2015 Nathan Kot. All rights reserved.
//

import UIKit
import RxMultipeer
import MultipeerConnectivity
import RxSwift
import RxCocoa

class ViewController: UIViewController {

  typealias I = MCPeerID

  @IBOutlet weak var advertiseButton: UIButton!
  @IBOutlet weak var browseButton: UIButton!
  @IBOutlet weak var yoButton: UIButton!
  @IBOutlet weak var outputButton: UIButton!
  @IBOutlet weak var disconnectButton: UIButton!

  var disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()

    let name = UIDevice.current.name
    print("\(name): Loading")

    let client = CurrentClient(
        session: MultipeerConnectivitySession(
                 displayName: name,
                 serviceType: "multipeerex",
                 encryptionPreference: .none))

    let other = client.connectedPeer().shareReplay(1)

    advertiseButton.rx.tap
    .subscribe(onNext: {
      print("\(name): begin advertising")
      client.stopBrowsing()
      client.startAdvertising()
    })
    .addDisposableTo(disposeBag)

    browseButton.rx.tap
    .subscribe(onNext: {
      print("\(name): begin browsing")
      client.stopAdvertising()
      client.startBrowsing()
    })
    .addDisposableTo(disposeBag)

    disconnectButton.rx.tap
    .subscribe(onNext: {
      print("\(name): disconnecting")
      client.disconnect()
    })
    .addDisposableTo(disposeBag)

    yoButton.rx.tap
    .withLatestFrom(client.connections())
    .map { (cs: [Client<I>]) -> Observable<Client<I>> in
      Observable.concat(cs.map { Observable.just($0) }) }
    .merge()
    .map { (c: Client<I>) -> Observable<()> in
      print("\(name): sending yo to \(c.iden)")
      return client.send(c, "yo")
    }
    .merge()
    .subscribe(onNext: { _ in })
    .addDisposableTo(disposeBag)

    Observable.combineLatest(client.connections(),
                  client.nearbyPeers()) { (connections, nearby) in
      return nearby.filter { (p, _) in
               connections.map { $0.iden }.index(of: p.iden) == nil
             }
    }
    .subscribe(onNext: {
      print("\(name): there are \($0.count) devices nearby")
      for p in $0 {
        print("\(name): connecting to \(p.0.iden)")
        client.connect(p.0)
      }
    })
    .addDisposableTo(disposeBag)

    // Just accept everything
    client.incomingConnections()
    .subscribe(onNext: { (_, _, respond) in respond(true) })
    .addDisposableTo(disposeBag)

    // Logging
    other
    .subscribe(onNext: { print("\(name): \($0.iden) successfully connected") })
    .addDisposableTo(disposeBag)

    client.disconnectedPeer()
    .subscribe(onNext: { print("\(name): \($0.iden) disconnected") })
    .addDisposableTo(disposeBag)

    client.receive()
    .subscribe(onNext: { (c, m: String) in print("\(name): received message '\(m)'") })
    .addDisposableTo(disposeBag)

    let stream = other
      .map { client.send($0, streamName: "hellothere") }
      .debug()
      .switchLatest()
      .shareReplay(1)

    outputButton.rx.tap
      .do(onNext: { _ in print("Attempting to send stream output") })
      .withLatestFrom(stream)
      .subscribe(onNext: { fetcher in fetcher([0x00, 0x89]) })
      .addDisposableTo(disposeBag)

    other.map { client.receive($0, streamName: "hellothere") }
      .switchLatest()
      .debug()
      .subscribe(onNext: { (d: [UInt8]) in
        print("Received stream data: \(d)")
      })
      .addDisposableTo(disposeBag)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}
