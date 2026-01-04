//
//  AppDelegate.swift
//  loota
//
//  Created by Jared Goolsby on 3/28/25.
//

import SwiftUI
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Create the SwiftUI view that provides the window contents.
    let contentView = ContentView()

    // Use a UIHostingController as window root view controller.
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIHostingController(rootView: contentView)
    self.window = window
    window.makeKeyAndVisible()
    return true
  }

  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return .portrait
  }

  // MARK: Universal Link Handling
  func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let incomingURL = userActivity.webpageURL
    else {
      print("AppDelegate: Not a web browsing activity or no URL.")
      return false
    }

    print("AppDelegate: Received Universal Link: \(incomingURL)")
    handleIncomingURL(incomingURL)
    return true
  }

  private func handleIncomingURL(_ url: URL) {
    print("DEBUG: AppDelegate - handleIncomingURL called with URL: \(url.absoluteString)")
    // Expected format: https://www.loota.fun/hunt/{huntId}
    let pathComponents = url.pathComponents
    print("DEBUG: AppDelegate - URL path components: \(pathComponents)")

    // Check if the path has at least "/hunt/{huntId}"
    guard pathComponents.count >= 3, pathComponents[1] == "hunt" else {
      print(
        "DEBUG: AppDelegate - URL path does not match expected /hunt/{huntId} format. Path: \(url.path)"
      )
      return
    }

    let huntId = pathComponents[2]
    print("DEBUG: AppDelegate - Extracted hunt ID: \(huntId)")

    // Use HuntDataManager to fetch hunt data (this handles user registration too)
    HuntDataManager.shared.fetchHunt(withId: huntId)
  }

  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }
}
