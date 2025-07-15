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
  @State private var userName = ""
  @State private var isInitializing = true
  @State private var showingSplash = true

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
      // AR View in the background
      // Condition to show ARViewContainer based on hunt type and data availability
      if (currentHuntType == .geolocation && !objectLocations.isEmpty)
        || (currentHuntType == .proximity && !proximityMarkers.isEmpty)
      {
        ARViewContainer(
          objectLocations: $objectLocations,
          referenceLocation: $locationManager.currentLocation.wrappedValue,
          statusMessage: $statusMessage,
          heading: $locationManager.heading,
          onCoinCollected: { collectedPinId in
            print("🎯 CONTENTVIEW: onCoinCollected called with pinId: \(collectedPinId)")
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
              print("🎯 CONTENTVIEW: Calling API with huntId: \(huntId), pinId: \(collectedPinId)")
              huntDataManager.collectPin(huntId: huntId, pinId: collectedPinId)
            } else {
              print("🎯 CONTENTVIEW: No huntId available for API call")
            }
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
        // Placeholder when no object is selected or no data loaded
        Color.gray.edgesIgnoringSafeArea(.all)
        VStack {
          Text("Select an object type or load hunt data")
            .foregroundColor(.white)
            .font(.title)

          // Display current hunt type and data counts for debugging
          Text("Hunt Type: \(currentHuntType.map { $0.rawValue } ?? "None")")
            .foregroundColor(.white)
            .font(.caption)
          Text("Geolocation Objects: \(objectLocations.count)")
            .foregroundColor(.white)
            .font(.caption)
          Text("Proximity Markers: \(proximityMarkers.count)")
            .foregroundColor(.white)
            .font(.caption)
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
    .alert("Welcome to Loota!", isPresented: $showingNamePrompt) {
      TextField("Enter your name", text: $userName)
      Button("OK") {
        print("🔥 DEBUG: OK button tapped in alert!")
        submitName()
      }
      Button("Use Anonymous", role: .cancel) {
        print("🔥 DEBUG: Anonymous button tapped in alert!")
        cancelNamePrompt()
      }
    } message: {
      Text("Please enter your name to participate in the hunt, or choose Anonymous.")
    }
    .onReceive(huntDataManager.$huntData) { huntData in
      if let huntData = huntData {
        print("🔥 DEBUG: Hunt data received, checking if name prompt needed")
        
        // Load the hunt data first
        loadHuntData(huntData)
        
        // Only show name prompt if we need to prompt AND we haven't shown it yet for this hunt
        if huntDataManager.shouldPromptForName {
          print("🔥 DEBUG: Name prompt needed, showing modal")
          showingNamePrompt = true
        } else {
          print("🔥 DEBUG: User already has name, joining hunt directly")
          // User already has a name, proceed with joining hunt
          huntDataManager.joinHunt(huntId: huntData.id)
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
  
  private func submitName() {
    print("🔥 DEBUG: submitName() called!")
    print("🔥 DEBUG: userName value: '\(userName)'")
    let finalName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
    let nameToUse = finalName.isEmpty ? "Anonymous" : finalName
    print("🔥 DEBUG: Using name: '\(nameToUse)'")
    
    huntDataManager.setUserName(nameToUse)
    print("🔥 DEBUG: Set user name, dismissing modal")
    
    // Join hunt after setting name
    if let huntData = huntDataManager.huntData {
      print("🔥 DEBUG: Hunt data exists, joining hunt: \(huntData.id)")
      huntDataManager.joinHunt(huntId: huntData.id)
    } else {
      print("🔥 DEBUG: No hunt data available")
    }
  }
  
  private func cancelNamePrompt() {
    print("🔥 DEBUG: cancelNamePrompt() called!")
    
    // Use "Anonymous" if user cancels
    huntDataManager.setUserName("Anonymous")
    print("🔥 DEBUG: Set name to Anonymous, dismissing modal")
    
    // Still try to join hunt with Anonymous name
    if let huntData = huntDataManager.huntData {
      print("🔥 DEBUG: Hunt data exists, joining hunt with Anonymous")
      huntDataManager.joinHunt(huntId: huntData.id)
    }
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
      print("ContentView loadHuntData: Total AR objects created: \(self.objectLocations.count)")

    case .proximity:
      print("ContentView loadHuntData: Processing \(huntData.pins.count) pins for proximity")
      self.proximityMarkers = []
      self.pinData = []
      
      for pin in huntData.pins {
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
      print("ContentView loadHuntData: Total proximity markers created: \(self.proximityMarkers.count)")
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

