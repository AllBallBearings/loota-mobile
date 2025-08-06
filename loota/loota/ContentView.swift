// ContentView.swift

import CoreLocation
//import DataModels  // Import DataModels to access ARObjectType, HuntType, ProximityMarkerData
import SwiftUI

public struct ContentView: View {
  @State private var coinsCollected: Int = 0
  @State private var animate: Bool = false
  @State private var selectedObject: ARObjectType = .none
  @State private var currentLocation: CLLocationCoordinate2D?
  @State private var objectLocations: [CLLocationCoordinate2D] = []
  @State private var proximityMarkers: [ProximityMarkerData] = []
  @State private var pinData: [PinData] = []
  @State private var statusMessage: String = ""
  @State private var currentHuntType: HuntType?
  @State private var handTrackingStatus: String = "Hand tracking ready"
  @State private var isDebugMode: Bool = false
  @State private var showSummoningHint: Bool = false

  @StateObject private var locationManager = LocationManager()
  @StateObject private var huntDataManager = HuntDataManager.shared
  @State private var showingNamePrompt = false
  @State private var showingJoinPrompt = false
  @State private var showingHuntConfirmation = false
  @State private var userName = ""
  @State private var phoneNumber = ""
  @State private var isInitializing = true
  @State private var showingSplash = true
  @State private var userConfirmedHunt = false
  @State private var confirmedHuntId: String? = nil

  public init() {
    print("DEBUG: ContentView - init() called.")
  }

  public var body: some View {
    ZStack {
      // Show splash screen first
      if showingSplash {
        SplashScreen()
          .transition(.opacity)
      }
      // Main app content (always present after splash)
      else {
        mainAppContent
          .disabled(isInitializing) // Disable interaction during loading
        
        // Loading indicator overlay
        if isInitializing {
          LoadingIndicator(message: "Initializing Hunt...", showProgress: true)
            .transition(.opacity)
        }
      }
    }
    .onAppear {
      // Show splash for 2 seconds, then start initialization
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        withAnimation(.easeInOut(duration: 0.5)) {
          showingSplash = false
        }
        
        // Start app initialization after splash
        initializeApp()
      }
    }
  }
  
  private var mainAppContent: some View {
    ZStack {
      // Main container ZStack
      // AR View in the background - only show after user has confirmed hunt participation
      // Condition to show ARViewContainer based on hunt type and user confirmation
      // Keep AR view active even when all loot is collected for better user experience
      if userConfirmedHunt && currentHuntType != nil {
        ARViewContainer(
          objectLocations: $objectLocations,
          referenceLocation: $locationManager.currentLocation.wrappedValue,
          statusMessage: $statusMessage,
          heading: $locationManager.heading,
          onCoinCollected: { collectedPinId in
            print("🎯 CONTENTVIEW: ===============================================")
            print("🎯 CONTENTVIEW: onCoinCollected called with pinId: \(collectedPinId)")
            print("🎯 CONTENTVIEW: Timestamp: \(Date())")
            coinsCollected += 1
            print("🎯 CONTENTVIEW: Counter incremented to: \(coinsCollected)")
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
              animate = true
            }
            // Reset animation after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              animate = false
            }

            if let huntId = huntDataManager.huntData?.id {
              print("🎯 CONTENTVIEW: Found huntId: \(huntId)")
              print("🎯 CONTENTVIEW: About to call huntDataManager.collectPin")
              print("🎯 CONTENTVIEW: Parameters - huntId: \(huntId), pinId: \(collectedPinId)")
              huntDataManager.collectPin(huntId: huntId, pinId: collectedPinId)
              print("🎯 CONTENTVIEW: huntDataManager.collectPin call completed")
            } else {
              print("🎯 CONTENTVIEW: ❌ NO HUNT ID AVAILABLE")
              print("🎯 CONTENTVIEW: huntDataManager.huntData: \(huntDataManager.huntData?.id ?? "nil")")
            }
            print("🎯 CONTENTVIEW: ===============================================")
          },
          objectType: $selectedObject,
          currentHuntType: $currentHuntType,
          proximityMarkers: $proximityMarkers,
          pinData: $pinData,
          handTrackingStatus: $handTrackingStatus,
          isDebugMode: $isDebugMode
        )
        // Use a stable ID that doesn't change during active gameplay
        .id("ar-view-\(currentHuntType?.rawValue ?? "none")")
        .edgesIgnoringSafeArea(.all)
      } else {
        // Placeholder when AR is not ready or hunt not confirmed
        Color.gray.edgesIgnoringSafeArea(.all)
        VStack {
          if showingHuntConfirmation {
            Text("Hunt Found!")
              .foregroundColor(.yellow)
              .font(.title)
            Text("Review details and confirm to join")
              .foregroundColor(.white.opacity(0.7))
              .font(.body)
          } else if currentHuntType != nil && !userConfirmedHunt {
            Text("Hunt Ready")
              .foregroundColor(.white)
              .font(.title)
            Text("Complete confirmation to start hunting")
              .foregroundColor(.white.opacity(0.7))
              .font(.body)
          } else {
            Text("Loota Treasure Hunt")
              .foregroundColor(.white)
              .font(.title)
            Text("Scan QR code or enter hunt ID to begin")
              .foregroundColor(.white.opacity(0.7))
              .font(.body)
          }

          // Display current hunt type and data counts for debugging (only in debug mode)
          if isDebugMode {
            Text("Hunt Type: \(currentHuntType.map { $0.rawValue } ?? "None")")
              .foregroundColor(.white)
              .font(.caption)
            Text("Geolocation Objects: \(objectLocations.count)")
              .foregroundColor(.white)
              .font(.caption)
            Text("Proximity Markers: \(proximityMarkers.count)")
              .foregroundColor(.white)
              .font(.caption)
            Text("User Confirmed: \(userConfirmedHunt ? "Yes" : "No")")
              .foregroundColor(.white)
              .font(.caption)
          }
        }
      }

      // VStack for Heading and Accuracy Display (Top Center) - Debug Mode Only
      if isDebugMode {
        VStack {
          Text(locationManager.trueHeadingString)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
          Text(locationManager.accuracyString)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
          Spacer()  // Pushes this VStack to the top
        }
        .padding(.top, 10)  // Add some padding from the top edge
        .frame(maxWidth: .infinity, alignment: .center)  // Center horizontally
      }

      // Summoning hint message (bottom center) - only when objects are within range
      if showSummoningHint {
        VStack {
          Spacer()
          
          Text("🧙‍♂️ If loot is just out of reach, then summon it with an outstretched hand")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .padding(.bottom, 120) // Above the debug panel
        }
        .frame(maxWidth: .infinity)
      }
      
      // UI Overlay VStack
      VStack {
        HStack(alignment: .top) {  // Top Row: Counter and Object Type Display
          // Animated counter in top left
          ZStack {
            Text("\(coinsCollected)")
              .font(.system(size: 36, weight: .heavy, design: .rounded))
              .foregroundColor(.yellow)
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
              .background(
                LinearGradient(
                  gradient: Gradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.7)]
                  ),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .cornerRadius(16)
              .shadow(color: .yellow.opacity(0.7), radius: animate ? 16 : 4)
              .scaleEffect(animate ? 1.4 : 1.0)
              .opacity(animate ? 1.0 : 0.85)
              .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animate)
          }
          .padding([.top, .leading], 16)

          Spacer()  // Pushes object type text to the right

          // Debug toggle and Loot type display
          VStack(alignment: .trailing) {
            // Top row with debug toggle and gesture help
            HStack(spacing: 8) {
              
              // Debug toggle button
              Button(action: {
                isDebugMode.toggle()
              }) {
                Text(isDebugMode ? "🐛 DEBUG" : "🎮 PLAY")
                  .font(.caption)
                  .fontWeight(.bold)
                  .foregroundColor(.white)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(isDebugMode ? Color.orange.opacity(0.9) : Color.black.opacity(0.8))
                  .cornerRadius(8)
                  .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
              }
            }
            
            // Text displaying selected loot type
            Text("Loot:")
              .font(.caption)
              .foregroundColor(.white)
            Text(selectedObject.rawValue)
              .font(.headline)
              .foregroundColor(.yellow)
          }
          .padding([.top, .trailing], 16)
        }

        Spacer()  // Pushes location display to bottom/right

        // Debug Information Panel - Only show in debug mode
        if isDebugMode {
          VStack(alignment: .leading, spacing: 8) {
            Text("Your Location:")
              .font(.headline)
              .foregroundColor(.white)
            Text(String(format: "%.6f", currentLocation?.latitude ?? 0))
              .font(.caption.monospacedDigit())
              .foregroundColor(.white)
            Text(String(format: "%.6f", currentLocation?.longitude ?? 0))
              .font(.caption.monospacedDigit())
              .foregroundColor(.white)

            // Display User Name
            Text("User Name: \(huntDataManager.userName ?? "N/A")")
              .font(.caption)
              .foregroundColor(.white)

            Divider()
              .background(Color.white)
              .padding(.vertical, 4)

            // Display info based on hunt type
            if currentHuntType == .geolocation {
            Text("Geolocation Objects (\(objectLocations.count)):")
              .font(.headline)
              .foregroundColor(.white)
            if let firstLocation = objectLocations.first {
              Text(String(format: "%.6f", firstLocation.latitude))
                .font(.caption.monospacedDigit())
                .foregroundColor(.yellow)
              Text(String(format: "%.6f", firstLocation.longitude))
                .font(.caption.monospacedDigit())
                .foregroundColor(.yellow)
            } else {
              Text("N/A")
                .font(.caption.monospacedDigit())
                .foregroundColor(.yellow)
            }
          } else if currentHuntType == .proximity {
            Text("Proximity Markers (\(proximityMarkers.count)):")
              .font(.headline)
              .foregroundColor(.white)
            // Optionally display info about the first proximity marker
            if let firstMarker = proximityMarkers.first {
              Text("Dist: \(String(format: "%.1f", firstMarker.dist))m, Dir: \(firstMarker.dir)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.yellow)
            } else {
              Text("N/A")
                .font(.caption.monospacedDigit())
                .foregroundColor(.yellow)
            }
          } else {
            Text("No Hunt Data Loaded")
              .font(.headline)
              .foregroundColor(.white)
          }

          Divider()
            .background(Color.white)
            .padding(.vertical, 4)

          // Hand Tracking Status
          Text("Hand Tracking:")
            .font(.headline)
            .foregroundColor(.white)
          Text(handTrackingStatus)
            .font(.caption)
            .foregroundColor(handTrackingStatus.contains("🚀") ? .green : .yellow)
            .multilineTextAlignment(.center)
            

          // Status message display (errors)
          Text(huntDataManager.errorMessage ?? statusMessage)
            .font(.headline)
            .foregroundColor(.red)
            .padding(.top, 8)

          // Join status message display (success messages)
          if let joinMessage = huntDataManager.joinStatusMessage {
            Text(joinMessage)
              .font(.headline)
              .foregroundColor(.green)
              .padding(.top, 4)
          }

          // On-screen debug indicators
          if currentHuntType != nil {
            Text("Data Fetched: YES")
              .font(.caption)
              .foregroundColor(.green)
          } else {
            Text("Data Fetched: NO")
              .font(.caption)
              .foregroundColor(.red)
          }

          if currentHuntType == .geolocation {
            Text("Parsed Objects: \(objectLocations.count)")
              .font(.caption)
              .foregroundColor(.green)
          } else if currentHuntType == .proximity {
            Text("Parsed Markers: \(proximityMarkers.count)")
              .font(.caption)
              .foregroundColor(.green)
          }
          }
          .padding()
          .background(Color.black.opacity(0.6))
          .cornerRadius(10)
          .padding()
        }
      }
      
      // Hunt join confirmation screen overlay
      if showingHuntConfirmation,
         let huntData = huntDataManager.huntData {
        HuntJoinConfirmationView(
          huntData: huntData,
          existingUserName: huntDataManager.userName,
          existingUserId: huntDataManager.userId,
          existingUserPhone: huntDataManager.userPhone,
          isPresented: $showingHuntConfirmation,
          onConfirm: { name, phone in
            confirmHuntParticipation(name: name, phone: phone)
          },
          onCancel: {
            cancelHuntParticipation()
          }
        )
        .transition(.opacity)
        .zIndex(1000) // Ensure it appears on top of everything
      }
      
      // Hunt completion screen overlay
      if huntDataManager.showCompletionScreen,
         let huntData = huntDataManager.huntData,
         let userId = huntDataManager.userId {
        HuntCompletionView(
          huntData: huntData,
          currentUserId: userId,
          isPresented: $huntDataManager.showCompletionScreen
        )
        .transition(.opacity)
        .zIndex(999) // Ensure it appears on top
      }
      
    }
    .onChange(of: selectedObject) { oldValue, newValue in
      handleSelectedObjectChange(oldValue, newValue)
    }
    .onChange(of: showingNamePrompt) { oldValue, newValue in
      print("🔥 DEBUG: showingNamePrompt changed from \(oldValue) to \(newValue)")
    }
    .onReceive(locationManager.$currentLocation) { location in
      currentLocation = location
      print("ContentView onReceive: Updated currentLocation: \(String(describing: location))")
      
      // Check if we should show summoning hint
      updateSummoningHintVisibility()
    }
    .onReceive(locationManager.$heading) { newHeading in
      print(
        "ContentView onReceive: Updated heading: \(String(describing: newHeading?.trueHeading))")
    }
    // Note: Old alert-based prompts replaced with HuntJoinConfirmationView modal
    // Keeping alert infrastructure for potential error dialogs or edge cases
    .onReceive(huntDataManager.$huntData) { huntData in
      if let huntData = huntData {
        print("🔥 DEBUG: Hunt data received")
        print("🔥 DEBUG: Hunt ID: \(huntData.id)")
        print("🔥 DEBUG: Hunt Name: '\(huntData.name ?? "nil")'")
        print("🔥 DEBUG: Hunt Description: '\(huntData.description ?? "nil")'")
        print("🔥 DEBUG: userConfirmedHunt: \(userConfirmedHunt)")
        print("🔥 DEBUG: confirmedHuntId: \(confirmedHuntId ?? "nil")")
        print("🔥 DEBUG: showingHuntConfirmation: \(showingHuntConfirmation)")
        
        // Load the hunt data first (but don't show AR yet - userConfirmedHunt is still false)
        loadHuntData(huntData)
        
        // Pre-fill user name if available
        if let existingName = huntDataManager.userName {
          userName = existingName
        }
        
        // Only show hunt confirmation if user hasn't already confirmed this specific hunt
        if confirmedHuntId != huntData.id {
          print("🔥 DEBUG: New hunt or user hasn't confirmed this hunt yet, showing confirmation modal")
          showingHuntConfirmation = true
        } else {
          print("🔥 DEBUG: User already confirmed hunt \(huntData.id), skipping confirmation modal")
        }
      }
    }
  }
  
  private func initializeApp() {
    print("ContentView initializeApp: Starting app initialization.")
    locationManager.requestAuthorization()
    locationManager.startUpdating()
    
    print(
      "ContentView initializeApp: objectLocations.count = \(objectLocations.count), proximityMarkers.count = \(proximityMarkers.count), selectedObject = \(selectedObject.rawValue), currentHuntType = \(String(describing: currentHuntType))"
    )
    
    // Don't show name prompt immediately - wait for hunt data and actual join attempt
    // Finish initialization after a short delay to allow location services to start
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation(.easeInOut(duration: 0.5)) {
        isInitializing = false
      }
    }
  }
  
  // Note: Old alert-based methods replaced with unified confirmHuntParticipation
  // Keeping for potential fallback scenarios or debug purposes
  
  private func submitName() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: submitName() called - should use confirmHuntParticipation instead")
  }
  
  private func cancelNamePrompt() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: cancelNamePrompt() called - should use cancelHuntParticipation instead")
  }
  
  private func joinHuntWithPhone() {
    // Legacy method - now handled by HuntJoinConfirmationView
    print("🔥 DEBUG: joinHuntWithPhone() called - should use confirmHuntParticipation instead")
  }
  
  private func confirmHuntParticipation(name: String, phone: String) {
    print("🔥 DEBUG: confirmHuntParticipation called with name: '\(name)', phone: '\(phone)'")
    
    // Update local state
    userName = name
    phoneNumber = phone
    
    // Update the user name in hunt manager if it changed
    let currentName = huntDataManager.userName
    if currentName != name {
      print("🔥 DEBUG: User name changed from '\(currentName ?? "nil")' to '\(name)' - updating")
      huntDataManager.setUserName(name)
    }
    
    // Update the user phone in hunt manager if it changed
    let currentPhone = huntDataManager.userPhone
    if currentPhone != phone {
      print("🔥 DEBUG: User phone changed from '\(currentPhone ?? "nil")' to '\(phone)' - updating")
      huntDataManager.setUserPhone(phone)
    }
    
    // Join the hunt with phone number
    if let huntData = huntDataManager.huntData {
      print("🔥 DEBUG: Joining hunt '\(huntData.id)' with updated user data")
      huntDataManager.joinHunt(huntId: huntData.id, phoneNumber: phone)
      
      // Mark hunt as confirmed and dismiss the confirmation screen
      userConfirmedHunt = true
      confirmedHuntId = huntData.id
      showingHuntConfirmation = false
      
      print("🔥 DEBUG: Hunt participation confirmed for huntId: \(huntData.id), AR will now be initialized")
    }
  }
  
  private func cancelHuntParticipation() {
    print("🔥 DEBUG: cancelHuntParticipation called")
    
    // Reset hunt data and state
    showingHuntConfirmation = false
    userConfirmedHunt = false
    confirmedHuntId = nil
    huntDataManager.huntData = nil
    
    // Clear hunt-related state
    currentHuntType = nil
    objectLocations = []
    proximityMarkers = []
    pinData = []
    selectedObject = .none
    
    print("🔥 DEBUG: Hunt participation cancelled, returning to initial state")
  }
  
  private func handleSelectedObjectChange(_ oldValue: ARObjectType, _ newValue: ARObjectType) {
    // Clear locations when object type changes to none.
    // This might need adjustment based on how objectType is used with hunt types
    if newValue == .none {
      objectLocations = []  // Only clear geolocation locations here?
      // proximityMarkers = [] // Should proximity markers be cleared? Probably not by objectType change.
      print(
        "ContentView onChange selectedObject: \(newValue.rawValue) - Object type set to None, clearing geolocation locations."
      )
    } else {
      print("ContentView onChange selectedObject: \(newValue.rawValue)")
    }
  }

  // Method to load hunt data from HuntDataManager
  private func loadHuntData(_ huntData: HuntData) {
    print(
      "ContentView loadHuntData: Received hunt data for ID: \(huntData.id), type: \(huntData.type.rawValue)"
    )
    // huntDataManager.joinHunt(huntId: huntData.id) // This is now called from HuntDataManager
    self.currentHuntType = huntData.type
    self.statusMessage = ""  // Clear any previous error messages

    switch huntData.type {
    case .geolocation:
      print("ContentView loadHuntData: Processing \(huntData.pins.count) pins for geolocation")
      self.objectLocations = []
      self.pinData = []
      
      for pin in huntData.pins {
        // Skip pins that have already been collected
        if pin.collectedByUserId != nil {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping collected Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Collected by: \(pin.collectedByUserId ?? "unknown")")
          continue
        }
        
        if let lat = pin.lat, let lng = pin.lng {
          let location = CLLocationCoordinate2D(latitude: lat, longitude: lng)
          self.objectLocations.append(location)
          self.pinData.append(pin)
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: AR Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Order: \(pin.order ?? -1) - Lat: \(lat), Lng: \(lng)")
        } else {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Missing coordinates")
        }
      }
      
      self.proximityMarkers = []
      if !self.objectLocations.isEmpty && self.selectedObject == .none {
        self.selectedObject = .coin
      }
      let collectedCount = huntData.pins.filter { $0.collectedByUserId != nil }.count
      print("ContentView loadHuntData: Total pins: \(huntData.pins.count), Collected: \(collectedCount), AR objects created: \(self.objectLocations.count)")

    case .proximity:
      print("ContentView loadHuntData: Processing \(huntData.pins.count) pins for proximity")
      self.proximityMarkers = []
      self.pinData = []
      
      for pin in huntData.pins {
        // Skip pins that have already been collected
        if pin.collectedByUserId != nil {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping collected Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Collected by: \(pin.collectedByUserId ?? "unknown")")
          continue
        }
        
        if let dist = pin.distanceFt, let dir = pin.directionStr {
          let marker = ProximityMarkerData(dist: dist * 0.3048, dir: dir)
          self.proximityMarkers.append(marker)
          self.pinData.append(pin)
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: AR Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Order: \(pin.order ?? -1) - \(dist)ft \(dir)")
        } else {
          let markerNumber = (pin.order ?? -1) + 1
          print("ContentView loadHuntData: Skipping Marker \(markerNumber) - ID: \(pin.id ?? "nil") - Missing proximity data")
        }
      }
      
      self.objectLocations = []
      self.selectedObject = .coin  // Default to coin for proximity
      let collectedCount = huntData.pins.filter { $0.collectedByUserId != nil }.count
      print("ContentView loadHuntData: Total pins: \(huntData.pins.count), Collected: \(collectedCount), Proximity markers created: \(self.proximityMarkers.count)")
    }
    
    // Check if summoning hint should be shown after loading hunt data
    updateSummoningHintVisibility()
  }


  // Method to check if summoning hint should be shown
  private func updateSummoningHintVisibility() {
    guard let currentLoc = currentLocation else {
      showSummoningHint = false
      return
    }
    
    // Check if hunt is loaded and has objects
    guard currentHuntType != nil, !objectLocations.isEmpty || !proximityMarkers.isEmpty else {
      showSummoningHint = false
      return
    }
    
    let proximityThreshold: Double = 30.48 // 100 feet in meters
    var hasNearbyObjects = false
    
    if currentHuntType == .geolocation {
      // Check distance to geolocation objects
      for objLocation in objectLocations {
        let objCLLocation = CLLocation(latitude: objLocation.latitude, longitude: objLocation.longitude)
        let userCLLocation = CLLocation(latitude: currentLoc.latitude, longitude: currentLoc.longitude)
        let distance = userCLLocation.distance(from: objCLLocation)
        
        if distance <= proximityThreshold {
          hasNearbyObjects = true
          break
        }
      }
    } else if currentHuntType == .proximity {
      // For proximity hunts, assume objects are within range (they're positioned relative to user)
      hasNearbyObjects = !proximityMarkers.isEmpty
    }
    
    showSummoningHint = hasNearbyObjects
  }

  // Method to display error messages from AppDelegate
  public func displayErrorMessage(_ message: String) {
    DispatchQueue.main.async {
      self.statusMessage = message
      self.objectLocations = []
      self.proximityMarkers = []
      self.currentHuntType = nil
      self.selectedObject = .none
      self.showSummoningHint = false
      print("ContentView displayErrorMessage: \(message)")
    }
  }
}

