import Foundation

public enum RxMultipeerError : ErrorType {
  case ConnectionError
  case UnknownError

  public var description: String {
    switch self {
      case ConnectionError: return "Could not establish connection with peer"
      case UnknownError: return "An unknown error occurred"
    }
  }
}
