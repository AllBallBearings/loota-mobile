import Foundation
import Combine

class AppClipHuntTracker: ObservableObject {
  static let shared = AppClipHuntTracker()

  private static let sharedDefaults = UserDefaults(suiteName: "group.allballbearings.loota") ?? .standard
  private static let completedHuntsKey = "appClipCompletedHuntIds"
  private static let maxFreeHunts = 2

  @Published private(set) var completedHuntIds: Set<String>

  var canStartNewHunt: Bool {
    completedHuntIds.count < Self.maxFreeHunts
  }

  var remainingHunts: Int {
    max(0, Self.maxFreeHunts - completedHuntIds.count)
  }

  private init() {
    let stored = Self.sharedDefaults.stringArray(forKey: Self.completedHuntsKey) ?? []
    completedHuntIds = Set(stored)
  }

  func recordHuntCompleted(huntId: String) {
    guard !completedHuntIds.contains(huntId) else { return }
    completedHuntIds.insert(huntId)
    Self.sharedDefaults.set(Array(completedHuntIds), forKey: Self.completedHuntsKey)
  }
}
