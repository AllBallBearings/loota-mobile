// ContentView.swift

import CoreLocation
//import DataModels  // Import DataModels to access ARObjectType, HuntType, ProximityMarkerData
import SwiftUI
import loota

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

  @StateObject private var locationManager = LocationManager()
  @StateObject private var huntDataManager = HuntDataManager.shared
  @State private var showingNamePrompt = false
  @State private var userName = ""

  public init() {
    print("DEBUG: ContentView - init() called.")
  }

  public var body: some View {
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
            coinsCollected += 1
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
              animate = true
            }
            // Reset animation after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              animate = false
            }

            if let huntId = huntDataManager.huntData?.id {
              huntDataManager.collectPin(huntId: huntId, pinId: collectedPinId)
            }
          },
          objectType: $selectedObject,
          currentHuntType: $currentHuntType,
          proximityMarkers: $proximityMarkers,
          pinData: $pinData
        )
        // Use a combined ID that changes when hunt type or relevant data changes
        .id(
          currentHuntType.map { $0.rawValue } ?? "none" + "\(objectLocations.count)"
            + "\(proximityMarkers.count)"
        )
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

      // VStack for Heading and Accuracy Display (Top Center)
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

          // Text displaying selected object type
          VStack(alignment: .trailing) {
            Text("Object:")
              .font(.caption)
              .foregroundColor(.white)
            Text(selectedObject.rawValue)
              .font(.headline)
              .foregroundColor(.yellow)
          }
          .padding([.top, .trailing], 16)
        }

        Spacer()  // Pushes location display to bottom/right

        // GPS Coordinates Display (Keep for debugging, maybe adapt for proximity?)
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
    .onChange(of: selectedObject) { oldValue, newValue in
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
    .onReceive(locationManager.$currentLocation) { location in
      currentLocation = location
      print("ContentView onReceive: Updated currentLocation: \(String(describing: location))")
    }
    .onReceive(locationManager.$heading) { newHeading in
      print(
        "ContentView onReceive: Updated heading: \(String(describing: newHeading?.trueHeading))")
    }
    .onAppear {
      print("ContentView onAppear: Requesting authorization and starting updates.")
      locationManager.requestAuthorization()
      locationManager.startUpdating()
      print(
        "ContentView onAppear: objectLocations.count = \(objectLocations.count), proximityMarkers.count = \(proximityMarkers.count), selectedObject = \(selectedObject.rawValue), currentHuntType = \(String(describing: currentHuntType))"
      )
      if huntDataManager.shouldPromptForName {
        showingNamePrompt = true
      }
    }
    .alert("Enter Your Name", isPresented: $showingNamePrompt, actions: {
      TextField("Name", text: $userName)
      Button("OK") {
        huntDataManager.setUserName(userName)
        showingNamePrompt = false
        // Join hunt after setting name
        if let huntData = huntDataManager.huntData {
          huntDataManager.joinHunt(huntId: huntData.id)
        }
      }
    }, message: {
      Text("Please enter your name to participate in the hunt.")
    })
    .onReceive(huntDataManager.$huntData) { huntData in
      if let huntData = huntData {
        // Check if user name prompt is needed when hunt data is received
        if huntDataManager.shouldPromptForName {
          showingNamePrompt = true
        } else {
          // User already has a name, proceed with joining hunt
          huntDataManager.joinHunt(huntId: huntData.id)
        }
        loadHuntData(huntData)
      }
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
  }


  // Method to display error messages from AppDelegate
  public func displayErrorMessage(_ message: String) {
    DispatchQueue.main.async {
      self.statusMessage = message
      self.objectLocations = []
      self.proximityMarkers = []
      self.currentHuntType = nil
      self.selectedObject = .none
      print("ContentView displayErrorMessage: \(message)")
    }
  }
}
