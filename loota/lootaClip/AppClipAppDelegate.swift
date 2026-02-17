import SwiftUI
import UIKit

@main
class AppClipAppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let contentView = AppClipContentView()

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIHostingController(rootView: contentView)
    self.window = window
    window.makeKeyAndVisible()
    return true
  }

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }

  // MARK: - App Clip Invocation URL Handling

  func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let incomingURL = userActivity.webpageURL
    else {
      print("AppClipAppDelegate: Not a web browsing activity or no URL.")
      return false
    }

    print("AppClipAppDelegate: Received App Clip invocation URL: \(incomingURL)")
    handleIncomingURL(incomingURL)
    return true
  }

  private func handleIncomingURL(_ url: URL) {
    let pathComponents = url.pathComponents

    guard pathComponents.count >= 3, pathComponents[1] == "hunt" else {
      print("AppClipAppDelegate: URL path does not match /hunt/{huntId} format.")
      return
    }

    let huntId = pathComponents[2]
    print("AppClipAppDelegate: Extracted hunt ID: \(huntId)")

    let tracker = AppClipHuntTracker.shared
    guard tracker.canStartNewHunt else {
      print("AppClipAppDelegate: Hunt limit reached, cannot start new hunt.")
      return
    }

    HuntDataManager.shared.fetchHunt(withId: huntId)
  }
}
