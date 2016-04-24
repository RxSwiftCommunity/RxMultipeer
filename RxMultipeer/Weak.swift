import Foundation

// Helper class to let us create a list of weak objects
class Weak<T: AnyObject> {
  weak var value : T?
  init (_ value: T) {
    self.value = value
  }
}
