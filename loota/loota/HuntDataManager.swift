// HuntDataManager.swift

import Combine
import Foundation
import SwiftUI

public class HuntDataManager: ObservableObject {
  public static let shared = HuntDataManager()

  @Published public var huntData: HuntData?
  @Published public var errorMessage: String?
  @Published public var joinStatusMessage: String?
  @Published public var isFetchingHunt: Bool = false
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
    // Check for existing user on app launch
    initializeUserData()
  }
  
  private func initializeUserData() {
    // Only check if we don't already have a userId
    guard userId == nil else { return }
    
    checkForExistingUser {
      // User data has been loaded if available
      print("DEBUG: HuntDataManager - initializeUserData: User initialization complete")
    }
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
  
  public func setUserPhone(_ phone: String) {
    print("DEBUG: HuntDataManager - setUserPhone called with phone: '\(phone)'")
    print("DEBUG: HuntDataManager - Current userPhone: '\(self.userPhone ?? "nil")'")
    print("DEBUG: HuntDataManager - Current userId: '\(self.userId ?? "nil")'")
    
    // If we have a userId but the backend doesn't support phone updates,
    // we need to clear the user data and register fresh with the correct phone
    if self.userId != nil {
      print("DEBUG: HuntDataManager - Backend doesn't support phone updates, clearing user data to register fresh")
      self.clearUserData()
    }
    
    self.userPhone = phone
    print("DEBUG: HuntDataManager - User phone set to '\(phone)', will register fresh user")
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
              
              guard let deviceId = UIDevice.current.vendorId else {
                print("DEBUG: HuntDataManager - checkAndSyncUserName: Device ID not available for update")
                completion()
                return
              }
              
              APIService.shared.updateUser(deviceId: deviceId, name: validLocalName) { updateResult in
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

    print("DEBUG: HuntDataManager - registerUserIfNeeded: Proceeding with user registration using device ID: \(deviceId)")
    performUserRegistration(deviceId: deviceId, completion: completion)
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
    DispatchQueue.main.async {
      self.isFetchingHunt = true
    }

    if lastHuntId != huntId {
        clearCollectedPins()
        lastHuntId = huntId
        hasJoinedHunt = false // Reset join status for new hunt
    }
    
    // Check for existing user data if we don't have it yet
    if userId == nil {
      checkForExistingUser { [weak self] in
        guard let self = self else { return }
        self.proceedWithHuntFetch(huntId: huntId)
      }
    } else {
      proceedWithHuntFetch(huntId: huntId)
    }
  }
  
  private func checkForExistingUser(completion: @escaping () -> Void) {
    guard let deviceId = UIDevice.current.vendorId else {
      print("DEBUG: HuntDataManager - checkForExistingUser: Device ID not available")
      completion()
      return
    }

    print("DEBUG: HuntDataManager - checkForExistingUser: Checking for existing user with device ID: \(deviceId)")
    print("DEBUG: HuntDataManager - checkForExistingUser: Making API call to: \(Environment.current.baseURL)/api/users?deviceId=\(deviceId)")
    
    APIService.shared.getUserByDeviceId(deviceId: deviceId) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        switch result {
        case .success(let userResponse):
          print("DEBUG: HuntDataManager - checkForExistingUser: ✅ API SUCCESS - Found existing user!")
          print("DEBUG: HuntDataManager - checkForExistingUser: User ID: \(userResponse.userId)")
          print("DEBUG: HuntDataManager - checkForExistingUser: Name: '\(userResponse.name)'")
          print("DEBUG: HuntDataManager - checkForExistingUser: Phone: '\(userResponse.phone ?? "nil")'")
          print("DEBUG: HuntDataManager - checkForExistingUser: PayPal ID: '\(userResponse.paypalId ?? "nil")'")
          print("DEBUG: HuntDataManager - checkForExistingUser: Device ID: '\(userResponse.deviceId ?? "nil")'")
          
          // Store the existing user data
          self.userId = userResponse.userId
          self.userName = userResponse.name
          self.userPhone = userResponse.phone
          
          print("DEBUG: HuntDataManager - checkForExistingUser: ✅ User data cached locally")
          print("DEBUG: HuntDataManager - checkForExistingUser: Final cached userId: '\(self.userId ?? "nil")'")
          print("DEBUG: HuntDataManager - checkForExistingUser: Final cached userName: '\(self.userName ?? "nil")'")
          print("DEBUG: HuntDataManager - checkForExistingUser: Final cached userPhone: '\(self.userPhone ?? "nil")'")
          
        case .failure(let error):
          if case .serverError(let statusCode, let message) = error, statusCode == 404 {
            print("DEBUG: HuntDataManager - checkForExistingUser: ℹ️ API returned 404 - No existing user found (this is normal for new users)")
            print("DEBUG: HuntDataManager - checkForExistingUser: 404 message: \(message ?? "nil")")
          } else {
            print("DEBUG: HuntDataManager - checkForExistingUser: ❌ API ERROR - \(error)")
            print("DEBUG: HuntDataManager - checkForExistingUser: Error description: \(error.localizedDescription)")
          }
        }
        
        print("DEBUG: HuntDataManager - checkForExistingUser: Final state - userId: \(self.userId ?? "nil"), userName: '\(self.userName ?? "nil")', userPhone: '\(self.userPhone ?? "nil")'")
        completion()
      }
    }
  }
  
  private func proceedWithHuntFetch(huntId: String) {
    APIService.shared.fetchHunt(withId: huntId, userId: self.userId) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(var data):
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Received hunt data with \(data.pins.count) pins")
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Hunt ID: '\(data.id)'")
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Hunt Name: '\(data.name ?? "nil")'")
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Hunt Description: '\(data.description ?? "nil")'")
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Hunt Type: '\(data.type.rawValue)'")

          // Sort pins by order field to ensure consistent numbering
          data.pins.sort { pin1, pin2 in
            let order1 = pin1.order ?? Int.max
            let order2 = pin2.order ?? Int.max
            return order1 < order2
          }
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: Pins sorted by order field")

          // Log all pin data with order-based numbering for debugging
          for pin in data.pins {
            let displayNumber = (pin.order ?? -1) + 1
            print("DEBUG: HuntDataManager - Marker \(displayNumber): ID: \(pin.id ?? "nil"), Order: \(pin.order ?? -1), Lat: \(pin.lat ?? 0), Lng: \(pin.lng ?? 0), CollectedBy: \(pin.collectedByUserId ?? "nil")")
          }

          // Check if server has pins that we think are collected (indicating server reset)
          let serverPinIDs = Set(data.pins.compactMap { $0.id })
          let conflictingPins = self.collectedPinIDs.intersection(serverPinIDs)

          if !conflictingPins.isEmpty {
            print("DEBUG: HuntDataManager - proceedWithHuntFetch: Server has \(conflictingPins.count) pins that we thought were collected, clearing cache")
            print("DEBUG: HuntDataManager - proceedWithHuntFetch: Conflicting pin IDs: \(conflictingPins)")
            self.clearCollectedPins()
          }

          // Check if user has already collected all remaining loot (rejoin scenario)
          if let userId = self.userId {
            let userCollectedPins = data.pins.filter { $0.collectedByUserId == userId }
            let uncollectedPins = data.pins.filter { $0.collectedByUserId == nil }

            print("DEBUG: HuntDataManager - proceedWithHuntFetch: User collected: \(userCollectedPins.count), Uncollected: \(uncollectedPins.count)")

            // If user collected pins and no uncollected pins remain, show completion screen
            if !userCollectedPins.isEmpty && uncollectedPins.isEmpty && !(data.isCompleted ?? false) {
              print("DEBUG: HuntDataManager - proceedWithHuntFetch: User has already collected all loot! Showing completion screen")
              self.huntData = data // Store full data with collected pins
              self.isFetchingHunt = false
              self.showCompletionScreen = true
              return
            }

            // If hunt is already completed, show completion screen with full data
            if data.isCompleted ?? false {
              print("DEBUG: HuntDataManager - proceedWithHuntFetch: Hunt is completed! Showing completion screen")
              self.huntData = data // Store full data
              self.isFetchingHunt = false
              self.showCompletionScreen = true
              return
            }
          }

          // For active gameplay, filter out collected pins so they don't appear in AR
          data.pins.removeAll { self.collectedPinIDs.contains($0.id ?? "") }
          print("DEBUG: HuntDataManager - proceedWithHuntFetch: After filtering collected pins, \(data.pins.count) pins remain for AR")

          self.huntData = data
          self.isFetchingHunt = false
          
          // Check if the current user is already a participant and extract their phone
          if let currentUserId = self.userId {
            if let participant = data.participants.first(where: { $0.userId == currentUserId }) {
              print("DEBUG: HuntDataManager - proceedWithHuntFetch: Found current user in participants!")
              print("DEBUG: HuntDataManager - proceedWithHuntFetch: Participant phone: '\(participant.participantPhone ?? "nil")'")
              
              // Update user phone if we have it from participants
              if let participantPhone = participant.participantPhone, !participantPhone.isEmpty {
                self.userPhone = participantPhone
                print("DEBUG: HuntDataManager - proceedWithHuntFetch: Updated userPhone from participants: '\(participantPhone)'")
              }
            } else {
              print("DEBUG: HuntDataManager - proceedWithHuntFetch: Current user not found in participants")
            }
          }
          
        case .failure(let error):
          self.errorMessage = error.localizedDescription
          self.joinStatusMessage = nil  // Clear any join messages on error
          self.isFetchingHunt = false
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

    // Check BEFORE removing if this is the last pin
    let remainingPinsBeforeRemoval = huntData.pins.count
    print("DEBUG: HuntDataManager - removePin: Remaining pins before removal: \(remainingPinsBeforeRemoval)")

    huntData.pins.removeAll { $0.id == pinId }
    self.huntData = huntData

    print("DEBUG: HuntDataManager - removePin: Remaining pins after removal: \(huntData.pins.count)")

    // Check if user has collected all remaining loot (pins array is now empty)
    if huntData.pins.isEmpty && !collectedPinIDs.isEmpty && !(huntData.isCompleted ?? false) {
      print("DEBUG: HuntDataManager - User collected all remaining loot! Refreshing hunt data for completion screen")
      print("DEBUG: HuntDataManager - Total collected pins: \(collectedPinIDs.count)")

      // Refetch hunt data to get full pin details with collectedByUserId
      refreshHuntDataForCompletion(huntId: huntData.id)
    }
  }

  private func refreshHuntDataForCompletion(huntId: String) {
    guard let userId = userId else { return }

    print("DEBUG: HuntDataManager - refreshHuntDataForCompletion: Fetching full hunt data")

    APIService.shared.fetchHunt(withId: huntId, userId: userId) { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self else { return }

        switch result {
        case .success(let fullHuntData):
          print("DEBUG: HuntDataManager - refreshHuntDataForCompletion: Successfully fetched full hunt data")
          print("DEBUG: HuntDataManager - refreshHuntDataForCompletion: Total pins: \(fullHuntData.pins.count)")

          let userCollected = fullHuntData.pins.filter { $0.collectedByUserId == userId }
          print("DEBUG: HuntDataManager - refreshHuntDataForCompletion: User collected: \(userCollected.count)")

          // Update huntData with full data (including collected pins)
          self.huntData = fullHuntData

          // Show completion screen
          self.showCompletionScreen = true

        case .failure(let error):
          print("DEBUG: HuntDataManager - refreshHuntDataForCompletion: Failed to fetch: \(error)")
          // Fallback: show completion screen anyway with current data
          self.showCompletionScreen = true
        }
      }
    }
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
