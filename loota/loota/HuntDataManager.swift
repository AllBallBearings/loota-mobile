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
  @AppStorage("userName") public var userName: String?
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
    userName == nil || userName?.isEmpty == true || userName == "Anonymous"
  }
  
  public var shouldPromptForName: Bool {
    // Prompt for name if user has no name OR if they have a userId but the local name suggests they were registered as Anonymous
    return isUserNameMissing || (userId != nil && (userName == nil || userName == "Anonymous"))
  }

  public func setUserName(_ name: String) {
    print("DEBUG: HuntDataManager - setUserName called with name: '\(name)'")
    print("DEBUG: HuntDataManager - Current userName: '\(self.userName ?? "nil")'")
    print("DEBUG: HuntDataManager - Current userId: '\(self.userId ?? "nil")'")
    
    // If we have a userId but the backend doesn't support name updates,
    // we need to clear the user data and register fresh with the correct name
    if self.userId != nil {
      print("DEBUG: HuntDataManager - Backend doesn't support name updates, clearing user data to register fresh")
      self.clearUserData()
    }
    
    self.userName = name
    print("DEBUG: HuntDataManager - User name set to '\(name)', will register fresh user")
  }
  
  private func clearUserData() {
    print("DEBUG: HuntDataManager - Clearing existing user data")
    self.userId = nil
    // Don't clear userName here - we want to keep the new name for registration
  }
  
  private func checkAndSyncUserName(userId: String, completion: @escaping () -> Void) {
    print("DEBUG: HuntDataManager - checkAndSyncUserName: Fetching user from database")
    
    APIService.shared.getUser(userId: userId) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        switch result {
        case .success(let userResponse):
          let databaseName = userResponse.name
          let localName = self.userName
          
          print("DEBUG: HuntDataManager - checkAndSyncUserName: Database name: '\(databaseName)'")
          print("DEBUG: HuntDataManager - checkAndSyncUserName: Local name: '\(localName ?? "nil")'")
          
          // Check if names don't match (considering nil, empty, and "Anonymous" as equivalent)
          let normalizedDbName = databaseName.isEmpty || databaseName == "Anonymous" ? nil : databaseName
          let normalizedLocalName = localName?.isEmpty == true || localName == "Anonymous" ? nil : localName
          
          if normalizedDbName != normalizedLocalName {
            print("DEBUG: HuntDataManager - checkAndSyncUserName: Names don't match! Need to sync.")
            
            if let validLocalName = normalizedLocalName {
              print("DEBUG: HuntDataManager - checkAndSyncUserName: Updating database with local name: '\(validLocalName)'")
              
              APIService.shared.updateUserName(userId: userId, newName: validLocalName) { updateResult in
                DispatchQueue.main.async {
                  switch updateResult {
                  case .success(_):
                    print("DEBUG: HuntDataManager - checkAndSyncUserName: Successfully updated database name")
                  case .failure(let error):
                    print("DEBUG: HuntDataManager - checkAndSyncUserName: Failed to update name: \(error)")
                  }
                  completion()
                }
              }
            } else {
              print("DEBUG: HuntDataManager - checkAndSyncUserName: No valid local name to sync")
              completion()
            }
          } else {
            print("DEBUG: HuntDataManager - checkAndSyncUserName: Names match, no sync needed")
            completion()
          }
          
        case .failure(let error):
          print("DEBUG: HuntDataManager - checkAndSyncUserName: Failed to fetch user: \(error)")
          completion()
        }
      }
    }
  }

  private func registerUserIfNeeded(completion: @escaping (Bool) -> Void) {
    if userId != nil {
      print("DEBUG: HuntDataManager - registerUserIfNeeded: userId already exists, skipping registration")
      completion(true)
      return
    }

    guard let deviceId = UIDevice.current.vendorId else {
      print("DEBUG: HuntDataManager - registerUserIfNeeded: Device ID not available")
      errorMessage = "Device ID not available."
      completion(false)
      return
    }

    let name = userName ?? "Anonymous"
    print("DEBUG: HuntDataManager - registerUserIfNeeded: Registering user with name: '\(name)'")

    APIService.shared.registerUser(name: name, phone: nil, payPalId: nil, deviceId: deviceId)
    { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let response):
          print("DEBUG: HuntDataManager - registerUserIfNeeded: Successfully registered user with userId: \(response.userId)")
          self.userId = response.userId
          completion(true)
        case .failure(let error):
          print("DEBUG: HuntDataManager - registerUserIfNeeded: Failed to register user: \(error.localizedDescription)")
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
    
    // Don't auto-register user when fetching hunt - let ContentView handle name prompt first
    APIService.shared.fetchHunt(withId: huntId) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(var data):
          print("DEBUG: HuntDataManager - fetchHunt: Received hunt data with \(data.pins.count) pins")
          
          // Sort pins by order field to ensure consistent numbering
          data.pins.sort { pin1, pin2 in
            let order1 = pin1.order ?? Int.max
            let order2 = pin2.order ?? Int.max
            return order1 < order2
          }
          print("DEBUG: HuntDataManager - fetchHunt: Pins sorted by order field")
          
          // Log all pin data with order-based numbering for debugging
          for pin in data.pins {
            let displayNumber = (pin.order ?? -1) + 1
            print("DEBUG: HuntDataManager - Marker \(displayNumber): ID: \(pin.id ?? "nil"), Order: \(pin.order ?? -1), Lat: \(pin.lat ?? 0), Lng: \(pin.lng ?? 0)")
          }
          
          // Check if server has pins that we think are collected (indicating server reset)
          let serverPinIDs = Set(data.pins.compactMap { $0.id })
          let conflictingPins = self.collectedPinIDs.intersection(serverPinIDs)
          
          if !conflictingPins.isEmpty {
            print("DEBUG: HuntDataManager - fetchHunt: Server has \(conflictingPins.count) pins that we thought were collected, clearing cache")
            print("DEBUG: HuntDataManager - fetchHunt: Conflicting pin IDs: \(conflictingPins)")
            self.clearCollectedPins()
          }
          
          data.pins.removeAll { self.collectedPinIDs.contains($0.id ?? "") }
          print("DEBUG: HuntDataManager - fetchHunt: After filtering collected pins, \(data.pins.count) pins remain")
          
          self.huntData = data
          // Don't auto-join hunt here - let ContentView handle user registration flow
        case .failure(let error):
          self.errorMessage = error.localizedDescription
          self.joinStatusMessage = nil  // Clear any join messages on error
        }
      }
    }
  }

  public func joinHunt(huntId: String) {
    print("DEBUG: HuntDataManager - joinHunt called for huntId: \(huntId)")
    print("DEBUG: HuntDataManager - joinHunt: Current userName: '\(self.userName ?? "nil")'")
    print("DEBUG: HuntDataManager - joinHunt: Current userId: '\(self.userId ?? "nil")'")
    
    // If we have a userId, first check if the database name matches our local name
    if let userId = self.userId {
      print("DEBUG: HuntDataManager - joinHunt: Checking database name for existing user")
      self.checkAndSyncUserName(userId: userId) { [weak self] in
        guard let self = self else { return }
        self.proceedWithJoinHunt(huntId: huntId)
      }
    } else {
      // No userId, proceed with normal registration
      self.proceedWithJoinHunt(huntId: huntId)
    }
  }
  
  private func proceedWithJoinHunt(huntId: String) {
    print("DEBUG: HuntDataManager - proceedWithJoinHunt called")
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { return }
      guard success, let userId = self.userId else {
        print("DEBUG: HuntDataManager - joinHunt: Failed to register. success: \(success), userId: \(self.userId ?? "nil")")
        self.errorMessage = "User not registered."
        return
      }
      
      // Check if already joined and skip if so
      if self.hasJoinedHunt {
        print("DEBUG: HuntDataManager - joinHunt: Already joined this hunt, skipping")
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
    print("DEBUG: HuntDataManager - collectPin called for huntId: \(huntId), pinId: \(pinId)")
    print("DEBUG: HuntDataManager - collectPin: hasJoinedHunt: \(hasJoinedHunt)")
    
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { return }
      print("DEBUG: HuntDataManager - collectPin: registerUserIfNeeded success: \(success)")
      print("DEBUG: HuntDataManager - collectPin: userId: \(self.userId ?? "nil")")
      
      guard success, let userId = self.userId else {
        print("DEBUG: HuntDataManager - collectPin: Failed - User not registered")
        self.errorMessage = "User not registered."
        return
      }

      print("DEBUG: HuntDataManager - collectPin: Attempting to collect pinId: \(pinId)")
      
      APIService.shared.collectPin(huntId: huntId, pinId: pinId, userId: userId) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let response):
            // Handle successful collection, e.g., remove pin from map
            print("DEBUG: HuntDataManager - collectPin: Successfully collected pin: \(response.pinId)")
            print("DEBUG: HuntDataManager - collectPin: Original pinId sent: \(pinId), Response pinId: \(response.pinId)")
            self.collectedPinIDs.insert(response.pinId)
            self.saveCollectedPinIDs()
            self.removePin(pinId: response.pinId)
          case .failure(let error):
            print("DEBUG: HuntDataManager - collectPin: Failed to collect pin \(pinId): \(error.localizedDescription)")
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
