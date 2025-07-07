// HuntDataManager.swift

import Combine
import Foundation
import SwiftUI

public class HuntDataManager: ObservableObject {
  public static let shared = HuntDataManager()

  @Published public var huntData: HuntData?
  @Published public var errorMessage: String?
  @Published public var joinStatusMessage: String?
  @AppStorage("userId") private var userId: String?
  @AppStorage("userName") private var userName: String?
  @AppStorage("collectedPinIDs") private var collectedPinIDsData: Data?
  @AppStorage("lastHuntId") private var lastHuntId: String?

  private var collectedPinIDs: Set<String> = []
  private var hasJoinedHunt: Bool = false

  private init() {
    loadCollectedPinIDs()
  }

  private func loadCollectedPinIDs() {
    guard let data = collectedPinIDsData else { return }
    if let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
      collectedPinIDs = ids
    }
  }

  private func saveCollectedPinIDs() {
    if let data = try? JSONEncoder().encode(collectedPinIDs) {
      collectedPinIDsData = data
    }
  }

  private func clearCollectedPins() {
    collectedPinIDs.removeAll()
    saveCollectedPinIDs()
  }

  public var isUserNameMissing: Bool {
    userName == nil || userName?.isEmpty == true
  }

  public func setUserName(_ name: String) {
    self.userName = name
    // After setting the name, we might need to re-trigger the registration process
    // if the user wasn't registered.
    registerUserIfNeeded { _ in }
  }

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

    let name = userName ?? "Anonymous"

    APIService.shared.registerUser(name: name, phone: nil, payPalId: nil, deviceId: deviceId)
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
    // Clear any previous status messages
    self.joinStatusMessage = nil
    self.errorMessage = nil

    if lastHuntId != huntId {
        clearCollectedPins()
        lastHuntId = huntId
        hasJoinedHunt = false // Reset join status for new hunt
    }
    
    registerUserIfNeeded { [weak self] success in
      guard let self = self, success else { return }

      APIService.shared.fetchHunt(withId: huntId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(var data):
            data.pins.removeAll { self.collectedPinIDs.contains($0.id ?? "") }
            self.huntData = data
            self.joinHunt(huntId: data.id) // Join hunt after fetching
          case .failure(let error):
            self.errorMessage = error.localizedDescription
            self.joinStatusMessage = nil  // Clear any join messages on error
          }
        }
      }
    }
  }

  public func joinHunt(huntId: String) {
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { return }
      guard success, let userId = self.userId, !self.hasJoinedHunt else {
        self.errorMessage = self.hasJoinedHunt ? "Already joined this hunt." : "User not registered."
        return
      }

      APIService.shared.joinHunt(huntId: huntId, userId: userId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let response):
            // Handle successful join with appropriate message based on rejoining status
            print("Successfully joined hunt: \(response.participationId), isRejoining: \(response.isRejoining)")
            
            // Clear any error messages on successful join
            self.errorMessage = nil
            
            if response.isRejoining {
              self.joinStatusMessage = "Welcome back! Rejoining hunt..."
            } else {
              self.joinStatusMessage = "Joined hunt! Welcome to the treasure hunt!"
            }
            self.hasJoinedHunt = true // Mark as joined
            
            // Clear the status message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
              self.joinStatusMessage = nil
            }
            
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
            self.collectedPinIDs.insert(response.pinId)
            self.saveCollectedPinIDs()
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
