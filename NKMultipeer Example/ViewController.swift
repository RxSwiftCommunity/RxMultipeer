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
    println("\(name): Loading")

    let client = CurrentClient(
        session: MultipeerConnectivitySession(
                 displayName: name,
                 serviceType: "multipeerex",
                 encryptionPreference: .None))

    advertiseButton.rx_tap
    >- subscribeNext {
      println("\(name): begin advertising")
      client.stopBrowsing()
      client.startAdvertising()
    }
    >- disposeBag.addDisposable

    browseButton.rx_tap
    >- subscribeNext {
      println("\(name): begin browsing")
      client.stopAdvertising()
      client.startBrowsing()
    }
    >- disposeBag.addDisposable

    disconnectButton.rx_tap
    >- subscribeNext {
      println("\(name): disconnecting")
      client.disconnect()
    }

    client.connections()
    >- sampleLatest(yoButton.rx_tap)
    >- map { (cs: [Client<I>]) -> Observable<Client<I>> in from(cs) }
    >- merge
    >- map { (c: Client<I>) -> Observable<()> in
      println("\(name): sending yo to \(c.iden)")
      return client.send(c, "yo")
    }
    >- merge
    >- subscribeNext { _ in }
    >- disposeBag.addDisposable

    combineLatest(client.connections(),
                  client.nearbyPeers()) { (connections, nearby) in
      return nearby.filter { (p, _) in
               find(connections.map { $0.iden }, p.iden) == nil
             }
    }
    >- subscribeNext {
      println("\(name): there are \(count($0)) devices nearby")
      for p in $0 {
        println("\(name): connecting to \(p.0.iden)")
        client.connect(p.0)
      }
    }
    >- disposeBag.addDisposable

    // Just accept everything
    client.incomingConnections()
    >- subscribeNext { (_, _, respond) in respond(true) }
    >- disposeBag.addDisposable

    // Logging
    client.connectedPeer()
    >- subscribeNext { println("\(name): \($0.iden) successfully connected") }
    >- disposeBag.addDisposable

    client.disconnectedPeer()
    >- subscribeNext { println("\(name): \($0.iden) disconnected") }
    >- disposeBag.addDisposable

    client.receive()
    >- subscribeNext { (c, m: String) in println("\(name): received message '\(m)'") }
    >- disposeBag.addDisposable
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}
