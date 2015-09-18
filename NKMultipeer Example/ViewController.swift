//
//  ViewController.swift
//  NKMultipeer Example
//
//  Created by Nathan Kot on 5/08/15.
//  Copyright (c) 2015 Nathan Kot. All rights reserved.
//

import UIKit
import NKMultipeer
import MultipeerConnectivity
import RxSwift
import RxCocoa

class ViewController: UIViewController {

  typealias I = MCPeerID

  @IBOutlet weak var advertiseButton: UIButton!
  @IBOutlet weak var browseButton: UIButton!
  @IBOutlet weak var yoButton: UIButton!
  @IBOutlet weak var disconnectButton: UIButton!

  var disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()

    let name = UIDevice.currentDevice().name
    print("\(name): Loading")

    let client = CurrentClient(
        session: MultipeerConnectivitySession(
                 displayName: name,
                 serviceType: "multipeerex",
                 encryptionPreference: .None))

    advertiseButton.rx_tap
    .subscribeNext {
      print("\(name): begin advertising")
      client.stopBrowsing()
      client.startAdvertising()
    }
    .addDisposableTo(disposeBag)

    browseButton.rx_tap
    .subscribeNext {
      print("\(name): begin browsing")
      client.stopAdvertising()
      client.startBrowsing()
    }
    .addDisposableTo(disposeBag)

    disconnectButton.rx_tap
    .subscribeNext {
      print("\(name): disconnecting")
      client.disconnect()
    }
    .addDisposableTo(disposeBag)

    client.connections()
    .sampleLatest(yoButton.rx_tap)
    .map { (cs: [Client<I>]) -> Observable<Client<I>> in cs.map { just($0) }.concat() }
    .merge()
    .map { (c: Client<I>) -> Observable<()> in
      print("\(name): sending yo to \(c.iden)")
      return client.send(c, "yo")
    }
    .merge()
    .subscribeNext { _ in }
    .addDisposableTo(disposeBag)

    combineLatest(client.connections(),
                  client.nearbyPeers()) { (connections, nearby) in
      return nearby.filter { (p, _) in
               connections.map { $0.iden }.indexOf(p.iden) == nil
             }
    }
    .subscribeNext {
      print("\(name): there are \($0.count) devices nearby")
      for p in $0 {
        print("\(name): connecting to \(p.0.iden)")
        client.connect(p.0)
      }
    }
    .addDisposableTo(disposeBag)

    // Just accept everything
    client.incomingConnections()
    .subscribeNext { (_, _, respond) in respond(true) }
    .addDisposableTo(disposeBag)

    // Logging
    client.connectedPeer()
    .subscribeNext { print("\(name): \($0.iden) successfully connected") }
    .addDisposableTo(disposeBag)

    client.disconnectedPeer()
    .subscribeNext { print("\(name): \($0.iden) disconnected") }
    .addDisposableTo(disposeBag)

    client.receive()
    .subscribeNext { (c, m: String) in print("\(name): received message '\(m)'") }
    .addDisposableTo(disposeBag)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}
