import Foundation

public enum RxMultipeerError : Error {
  case connectionError
  case unknownError
  case resourceError(String)

  public var description: String {
    switch self {
      case .connectionError: return "Could not establish connection with peer"
      case .unknownError: return "An unknown error occurred"
      case let .resourceError(s): return s
    }
  }
}
