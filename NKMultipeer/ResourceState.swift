import Foundation

public enum ResourceState {
  case Starting
  case Finished(NSURL)
  case Errored(NSError)

  public func fromFinished() -> NSURL? {
    switch self {
    case .Finished(let u): return u
    default: return nil
    }
  }
}
