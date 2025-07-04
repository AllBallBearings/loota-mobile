// HuntDataManager.swift

import Combine
import Foundation
import SwiftUI

public class HuntDataManager: ObservableObject {
  public static let shared = HuntDataManager()

  @Published public var huntData: HuntData?
  @Published public var errorMessage: String?
  @AppStorage("userId") private var userId: String?

  private init() {}

  private func registerUserIfNeeded(completion: @escaping (Bool) -> Void) {
    if userId != nil {
      completion(true)
      return
    }

    guard let deviceId = UIDevice.current.vendorId else {
      errorMessage = "Device ID not available."
      completion(false)
      return
    }

    APIService.shared.registerUser(name: "Anonymous", phone: nil, payPalId: nil, deviceId: deviceId)
    { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let response):
          self.userId = response.userId
          completion(true)
        case .failure(let error):
          self.errorMessage = error.localizedDescription
          completion(false)
        }
      }
    }
  }

  public func fetchHunt(withId huntId: String) {
    registerUserIfNeeded { [weak self] success in
      guard let self = self, success else { return }

      APIService.shared.fetchHunt(withId: huntId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let data):
            self.huntData = data
          case .failure(let error):
            self.errorMessage = error.localizedDescription
          }
        }
      }
    }
  }

  public func joinHunt(huntId: String) {
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { return }
      guard success, let userId = self.userId else {
        self.errorMessage = "User not registered."
        return
      }

      APIService.shared.joinHunt(huntId: huntId, userId: userId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let response):
            // Handle successful join, maybe update UI or state
            print("Successfully joined hunt: \(response.participationId)")
          case .failure(let error):
            self.errorMessage = error.localizedDescription
          }
        }
      }
    }
  }

  public func collectPin(huntId: String, pinId: String) {
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { return }
      guard success, let userId = self.userId else {
        self.errorMessage = "User not registered."
        return
      }

      APIService.shared.collectPin(huntId: huntId, pinId: pinId, userId: userId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let response):
            // Handle successful collection, e.g., remove pin from map
            print("Successfully collected pin: \(response.pinId)")
            self.removePin(pinId: response.pinId)
          case .failure(let error):
            self.errorMessage = error.localizedDescription
          }
        }
      }
    }
  }

  private func removePin(pinId: String) {
    guard var huntData = huntData else { return }
    huntData.pins.removeAll { $0.id == pinId }
    self.huntData = huntData
  }
}
