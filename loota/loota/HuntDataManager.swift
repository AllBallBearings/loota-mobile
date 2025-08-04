// HuntDataManager.swift

import Combine
import Foundation
import SwiftUI

public class HuntDataManager: ObservableObject {
  public static let shared = HuntDataManager()

  @Published public var huntData: HuntData?
  @Published public var errorMessage: String?
  @Published public var joinStatusMessage: String?
  @Published public var showCompletionScreen: Bool = false
  @AppStorage("userId") public var userId: String?
  @AppStorage("userName") public var userName: String?
  @AppStorage("userPhone") public var userPhone: String?
  @AppStorage("collectedPinIDs") private var collectedPinIDsData: Data?
  @AppStorage("lastHuntId") private var lastHuntId: String?

  private var collectedPinIDs: Set<String> = []
  private var hasJoinedHunt: Bool = false
  private var completionCheckTimer: Timer?

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
    self.userPhone = nil
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

    print("DEBUG: HuntDataManager - registerUserIfNeeded: Checking for existing user with device ID: \(deviceId)")
    
    // First check if user already exists with this device ID
    APIService.shared.getUserByDeviceId(deviceId: deviceId) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        switch result {
        case .success(let userResponse):
          print("DEBUG: HuntDataManager - registerUserIfNeeded: Found existing user!")
          print("DEBUG: HuntDataManager - registerUserIfNeeded: User ID: \(userResponse.userId)")
          print("DEBUG: HuntDataManager - registerUserIfNeeded: Name: \(userResponse.name)")
          print("DEBUG: HuntDataManager - registerUserIfNeeded: Phone: \(userResponse.phone ?? "nil")")
          
          // Store the existing user data
          self.userId = userResponse.userId
          self.userName = userResponse.name
          self.userPhone = userResponse.phone
          
          completion(true)
          
        case .failure(let error):
          // 404 means user doesn't exist - proceed with registration
          if case .serverError(let statusCode, _) = error, statusCode == 404 {
            print("DEBUG: HuntDataManager - registerUserIfNeeded: No existing user found, proceeding with registration")
            self.performUserRegistration(deviceId: deviceId, completion: completion)
          } else {
            print("DEBUG: HuntDataManager - registerUserIfNeeded: Error checking for existing user: \(error)")
            self.errorMessage = error.localizedDescription
            completion(false)
          }
        }
      }
    }
  }
  
  private func performUserRegistration(deviceId: String, completion: @escaping (Bool) -> Void) {
    let name = userName ?? "Anonymous"
    print("DEBUG: HuntDataManager - performUserRegistration: Registering new user with name: '\(name)'")

    APIService.shared.registerUser(name: name, phone: nil, payPalId: nil, deviceId: deviceId) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let response):
          print("DEBUG: HuntDataManager - performUserRegistration: Successfully registered user with userId: \(response.userId)")
          self.userId = response.userId
          completion(true)
        case .failure(let error):
          print("DEBUG: HuntDataManager - performUserRegistration: Failed to register user: \(error.localizedDescription)")
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

  public func joinHunt(huntId: String, phoneNumber: String) {
    print("DEBUG: HuntDataManager - joinHunt called for huntId: \(huntId), phone: \(phoneNumber)")
    print("DEBUG: HuntDataManager - joinHunt: Current userName: '\(self.userName ?? "nil")'")
    print("DEBUG: HuntDataManager - joinHunt: Current userId: '\(self.userId ?? "nil")'")
    
    // If we have a userId, first check if the database name matches our local name
    if let userId = self.userId {
      print("DEBUG: HuntDataManager - joinHunt: Checking database name for existing user")
      self.checkAndSyncUserName(userId: userId) { [weak self] in
        guard let self = self else { return }
        self.proceedWithJoinHunt(huntId: huntId, phoneNumber: phoneNumber)
      }
    } else {
      // No userId, proceed with normal registration
      self.proceedWithJoinHunt(huntId: huntId, phoneNumber: phoneNumber)
    }
  }
  
  private func proceedWithJoinHunt(huntId: String, phoneNumber: String) {
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

      APIService.shared.joinHunt(huntId: huntId, userId: userId, phoneNumber: phoneNumber) { result in
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
            
            // Start hunt completion polling
            self.startCompletionPolling(huntId: huntId)
            
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
    print("🎯 HuntDataManager - collectPin called for huntId: \(huntId), pinId: \(pinId)")
    print("🎯 HuntDataManager - collectPin: hasJoinedHunt: \(hasJoinedHunt)")
    print("🎯 HuntDataManager - collectPin: Current time: \(Date())")
    
    registerUserIfNeeded { [weak self] success in
      guard let self = self else { 
        print("🎯 HuntDataManager - collectPin: Self is nil, aborting")
        return 
      }
      print("🎯 HuntDataManager - collectPin: registerUserIfNeeded success: \(success)")
      print("🎯 HuntDataManager - collectPin: userId: \(self.userId ?? "nil")")
      
      guard success, let userId = self.userId else {
        print("🎯 HuntDataManager - collectPin: FAILED - User not registered. success: \(success), userId: \(self.userId ?? "nil")")
        self.errorMessage = "User not registered."
        return
      }

      print("🎯 HuntDataManager - collectPin: About to call APIService.collectPin with:")
      print("🎯   - huntId: \(huntId)")
      print("🎯   - pinId: \(pinId)")  
      print("🎯   - userId: \(userId)")
      
      APIService.shared.collectPin(huntId: huntId, pinId: pinId, userId: userId) { result in
        print("🎯 HuntDataManager - collectPin: APIService callback received")
        DispatchQueue.main.async {
          switch result {
          case .success(let response):
            print("🎯 HuntDataManager - collectPin: ✅ SUCCESS - Collected pin: \(response.pinId)")
            print("🎯 HuntDataManager - collectPin: Response message: \(response.message)")
            print("🎯 HuntDataManager - collectPin: Original pinId sent: \(pinId), Response pinId: \(response.pinId)")
            self.collectedPinIDs.insert(response.pinId)
            self.saveCollectedPinIDs()
            self.removePin(pinId: response.pinId)
            print("🎯 HuntDataManager - collectPin: Pin removed from local state")
          case .failure(let error):
            print("🎯 HuntDataManager - collectPin: ❌ FAILED to collect pin \(pinId)")
            print("🎯 HuntDataManager - collectPin: Error: \(error)")
            print("🎯 HuntDataManager - collectPin: Error description: \(error.localizedDescription)")
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
  
  // MARK: - Hunt Completion Detection
  
  private func startCompletionPolling(huntId: String) {
    print("DEBUG: HuntDataManager - Starting completion polling for hunt: \(huntId)")
    
    // Stop any existing timer
    completionCheckTimer?.invalidate()
    
    // Poll every 10 seconds
    completionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
      self?.checkHuntCompletion(huntId: huntId)
    }
  }
  
  private func checkHuntCompletion(huntId: String) {
    guard let userId = self.userId else { return }
    
    APIService.shared.fetchHuntWithUserContext(huntId: huntId, userId: userId) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        switch result {
        case .success(let updatedHunt):
          let wasCompleted = self.huntData?.isCompleted ?? false
          let isNowCompleted = updatedHunt.isCompleted ?? false
          
          // Check if hunt just completed
          if isNowCompleted && !wasCompleted {
            print("DEBUG: HuntDataManager - Hunt completed! Winner: \(updatedHunt.winnerId ?? "unknown")")
            self.huntData = updatedHunt
            self.showCompletionScreen = true
            self.stopCompletionPolling()
          }
          
        case .failure(let error):
          print("DEBUG: HuntDataManager - Failed to check hunt completion: \(error)")
        }
      }
    }
  }
  
  private func stopCompletionPolling() {
    completionCheckTimer?.invalidate()
    completionCheckTimer = nil
  }
  
  public func dismissCompletionScreen() {
    showCompletionScreen = false
  }
  
  // Computed properties for completion screen
  public var isWinner: Bool {
    guard let huntData = huntData, let winnerId = huntData.winnerId, let userId = userId else {
      return false
    }
    return winnerId == userId
  }
  
  deinit {
    stopCompletionPolling()
  }
}
