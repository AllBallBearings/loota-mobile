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
    // Load API key from Info.plist for better security
    // Set this in Xcode: Project Settings > Info > Custom iOS Target Properties
    // Add key: LOOTA_API_KEY with value from secure storage
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "LOOTA_API_KEY") as? String {
      return apiKey
    }
    // Fallback for development (remove in production)
    return "AYOYloSpuBCcwAz5xMFs6Iei/e4UXrBsTmr8jAj063KWcFn46m5Jzj+FNq2hAYdD"
  }
}
