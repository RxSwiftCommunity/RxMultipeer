import Foundation

public enum ResourceState {
  case progress(Progress)
  case finished(URL)
  case errored(Error)

  public func fromFinished() -> URL? {
    switch self {
    case .finished(let u): return u
    default: return nil
    }
  }
}
