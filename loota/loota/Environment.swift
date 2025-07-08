import Foundation

enum Environment {
  case production
  case staging

  static var current: Environment {
    #if DEBUG
      return .staging
    #else
      return .production
    #endif
  }

  var baseURL: String {
    switch self {
    case .production:
      return "https://www.loota.fun"
    case .staging:
      return "https://staging.loota.fun"
    }
  }

  var apiKey: String {
    // This key should ideally be loaded from a secure source (e.g., Xcode build settings, environment variables, or Keychain)
    // For demonstration, it's hardcoded here.
    return "AYOYloSpuBCcwAz5xMFs6Iei/e4UXrBsTmr8jAj063KWcFn46m5Jzj+FNq2hAYdD"
  }
}
