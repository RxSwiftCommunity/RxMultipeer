import NKMultipeer
import Quick
import Nimble
import RxSwift

public class IntegrationSpec : QuickSpec {

  override public func spec() {

    var disposeBag = DisposeBag()

    describe("two clients") {

      var clientone: CurrentClient<MockIden, MockSession>?
      var clienttwo: CurrentClient<MockIden, MockSession>?

      beforeEach {
        disposeBag = DisposeBag()
        clientone = nil
        clienttwo = nil
        MockSession.reset()
        clientone = CurrentClient(session: MockSession(name: "one"))
        clienttwo = CurrentClient(session: MockSession(name: "two"))
      }

      describe("client two advertises") {

        beforeEach {
          // Advertise and always accept connections
          clienttwo!.startAdvertising()
          clienttwo!.incomingConnections()
          >- subscribeNext { (client, respond) in
            respond(true) }
          >- disposeBag.addDisposable
        }

        it("allows client one to browse for client two") {
          waitUntil { done in
            clientone!.startBrowsing()
            clientone!.nearbyPeers()
            >- filter { $0.count > 0 }
            >- subscribeNext { clients in
              expect(clients[0].iden).to(equal(clienttwo!.iden))
              done()
            }
            >- disposeBag.addDisposable
            return
          }
          return
        }

        it("allows clients to connect with eachother") {
          waitUntil { done in
            clientone!.connectedPeer()
            >- take(1)
            >- subscribeNext { _ in done() }
            >- disposeBag.addDisposable

            clientone!.connect(clienttwo!)
          }
        }

        it("alters connections when clients connect") {
          waitUntil { done in
            combineLatest(
              clientone!.connections(),
              clienttwo!.connections()) { count($0) + count($1) }
            >- subscribeNext { if $0 == 2 { done() } }
            >- disposeBag.addDisposable

            clientone!.connect(clienttwo!)
          }
        }

        describe("clients are connected") {

          beforeEach {
            waitUntil { done in
              clientone!.connectedPeer()
              >- take(1)
              >- subscribeNext { _ in done() }
              >- disposeBag.addDisposable

              clientone!.connect(clienttwo!)
            }
          }

          it("allows client two to disconnect") {
            waitUntil { done in
              combineLatest(
                clientone!.disconnectedPeer(),
                clientone!.connections()) { ($0, $1) }
              >- take(1)
              >- subscribeNext { (_, connections) in
                expect(count(connections)).to(equal(0))
                done()
              }
              >- disposeBag.addDisposable

              clienttwo!.disconnect()
            }
          }

          it("lets clients send strings to eachother") {
            waitUntil { done in
              clienttwo!.receive()
              >- subscribeNext { (client: Client, string: String) in
                expect(client.iden).to(equal(clientone!.iden))
                expect(string).to(equal("hello"))
              }
              >- disposeBag.addDisposable

              clientone!.send(clienttwo!, "hello")
              >- subscribeCompleted { done() }
              >- disposeBag.addDisposable
            }
          }

          it("lets clients send resource urls to each other") {
            waitUntil { done in
              clienttwo!.receive()
              >- subscribeNext { (client: Client, name: String, url: NSURL) in
                expect(client.iden).to(equal(clientone!.iden))
                expect(name).to(equal("txt file"))
                let contents = NSString(data: NSData(contentsOfURL: url)!, encoding: NSUTF8StringEncoding)
                expect(contents).to(equal("hello there this is random data"))
              }
              >- disposeBag.addDisposable

              let url = NSBundle(forClass: self.dynamicType).URLForResource("Data", withExtension: "txt")
              clientone!.send(clienttwo!, name: "txt file", url: url!)
              >- subscribeCompleted { done() }
              >- disposeBag.addDisposable
            }
          }

          it("lets clients send JSON data to each other via foundation objects") {
            waitUntil { done in
              clienttwo!.receive()
              >- subscribeNext { (client: Client, json: [String: AnyObject]) in
                expect(client.iden).to(equal(clientone!.iden))
                expect(json["one"] as? String).to(equal("two"))
                expect(json["three"] as? Int).to(equal(4))
                expect(json["five"] as? Bool).to(beTrue())
              }
              >- disposeBag.addDisposable

              clientone!.send(clienttwo!, [
                "one": "two", "three": 4, "five": true])
              >- subscribeCompleted { done() }
              >- disposeBag.addDisposable
            }
          }

        }

      }

    }

  }

}
