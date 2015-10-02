import Foundation

public enum NKMultipeerError : ErrorType {
  case ConnectionError

  public var description: String {
    switch self {
      case ConnectionError: return "Could not establish connection with peer"
    }
  }
}
