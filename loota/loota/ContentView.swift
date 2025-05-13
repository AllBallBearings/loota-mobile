// ContentView.swift

import SwiftUI
import CoreLocation
import Foundation // Needed for parsing direction strings

// Define HuntType enum
enum HuntType: String, Decodable {
    case geolocation
    case proximity
}

// Define ProximityMarkerData struct
struct ProximityMarkerData: Codable, Identifiable {
    let id: UUID // Make id a let property
    let dist: Double // Distance in meters
    let dir: String  // Direction string, e.g., "N32E"

    // Custom initializer for Codable to generate ID locally
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dist = try container.decode(Double.self, forKey: .dist)
        dir = try container.decode(String.self, forKey: .dir)
        id = UUID() // Generate a new UUID when decoding
    }

    // Define CodingKeys to exclude 'id' from decoding if it were present in JSON
    enum CodingKeys: String, CodingKey {
        case dist
        case dir
    }
}

enum ARObjectType: String, CaseIterable, Identifiable {
    case none = "None"
    case coin = "Coin"
    case dollarSign = "Dollar Sign"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var coinsCollected: Int = 0
    @State private var animate: Bool = false
    @State private var selectedObject: ARObjectType = .none // Still used for geolocation, or maybe just default model
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var objectLocations: [CLLocationCoordinate2D] = [] // Used for geolocation hunt
    @State private var proximityMarkers: [ProximityMarkerData] = [] // Used for proximity hunt
    @State private var statusMessage: String = "" // Add status message state
    @State private var currentHuntType: HuntType? // Track the active hunt type
    
    @StateObject private var locationManager = LocationManager()
    
    // Helper struct for JSON decoding (Geolocation)
    struct PinLocation: Codable {
        let lat: Double
        let lng: Double
    }
    
    var body: some View {
        ZStack {
            // Main container ZStack
            // AR View in the background
            let _ = print("ContentView body: currentHuntType = \(String(describing: currentHuntType)), objectLocations.count = \(objectLocations.count), proximityMarkers.count = \(proximityMarkers.count), refLocation = \(String(describing: locationManager.currentLocation)), heading = \(String(describing: locationManager.heading?.trueHeading))")
            
            // Condition to show ARViewContainer based on hunt type and data availability
            if (currentHuntType == .geolocation && !objectLocations.isEmpty) ||
               (currentHuntType == .proximity && !proximityMarkers.isEmpty) {
                
                let _ = print("ContentView: ARViewContainer WILL be created.")
                ARViewContainer(
                    objectLocations: $objectLocations, // Pass array binding (used by geolocation)
                    referenceLocation: $locationManager.currentLocation.wrappedValue,
                    statusMessage: $statusMessage, // Add status message binding
                    heading: $locationManager.heading, // Pass heading binding
                    onCoinCollected: {
                        coinsCollected += 1
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
                            animate = true
                        }
                        // Reset animation after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            animate = false
                        }
                    },
                    objectType: $selectedObject, // Use $ to pass the binding (used by geolocation)
                    currentHuntType: $currentHuntType, // Pass new binding
                    proximityMarkers: $proximityMarkers // Pass new binding
                )
                // Use a combined ID that changes when hunt type or relevant data changes
                .id(currentHuntType.map { $0.rawValue } ?? "none" + "\(objectLocations.count)" + "\(proximityMarkers.count)")
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
                 let _ = print("ContentView: ARViewContainer WILL NOT be created. currentHuntType: \(String(describing: currentHuntType)), objectLocations.isEmpty: \(objectLocations.isEmpty), proximityMarkers.isEmpty: \(proximityMarkers.isEmpty)")
            }

            // UI Overlay VStack
            VStack {
                HStack(alignment: .top) { // Top Row: Counter and Object Type Display
                    // Animated counter in top left
                    ZStack {
                        Text("\(coinsCollected)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.7)]),
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

                    Spacer() // Pushes object type text to the right

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

                Spacer() // Pushes location display to bottom/right

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
                    
                    // Status message display
                    Text(statusMessage)
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(.top, 8)
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
                 objectLocations = [] // Only clear geolocation locations here?
                 // proximityMarkers = [] // Should proximity markers be cleared? Probably not by objectType change.
                 print("ContentView onChange selectedObject: \(newValue.rawValue) - Object type set to None, clearing geolocation locations.")
            } else {
                print("ContentView onChange selectedObject: \(newValue.rawValue)")
            }
        }
        .onReceive(locationManager.$currentLocation) { location in
            currentLocation = location
            print("ContentView onReceive: Updated currentLocation: \(String(describing: location))")
        }
        .onReceive(locationManager.$heading) { newHeading in
            print("ContentView onReceive: Updated heading: \(String(describing: newHeading?.trueHeading))")
        }
        .onAppear {
            print("ContentView onAppear: Requesting authorization and starting updates.")
            locationManager.requestAuthorization()
            locationManager.startUpdating()

            // Check for launch arguments
            let arguments = ProcessInfo.processInfo.arguments
            if let urlIndex = arguments.firstIndex(of: "-appLaunchURL"), urlIndex + 1 < arguments.count {
                let urlString = arguments[urlIndex + 1]
                if let url = URL(string: urlString) {
                    print("ContentView onAppear: Received launch argument URL: \(url)")
                    processLaunchURL(url) // Call the new processing function
                } else {
                    print("ContentView onAppear: Failed to create URL from launch argument: \(urlString)")
                }
            } else {
                print("ContentView onAppear: No -appLaunchURL argument found.")
            }
            print("ContentView onAppear: objectLocations.count = \(objectLocations.count), proximityMarkers.count = \(proximityMarkers.count), selectedObject = \(selectedObject.rawValue), currentHuntType = \(String(describing: currentHuntType))")
        }
        // .onOpenURL can be added back later if needed for real URL launches
        // .onOpenURL { url in
        //     print("Received URL via onOpenURL: \(url)")
        //     processLaunchURL(url) // Call the new processing function
        // }
    }

    // Renamed and updated URL parsing function
    func processLaunchURL(_ url: URL) {
        print("ContentView processLaunchURL: START - Attempting to parse URL: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            print("ContentView processLaunchURL: Could not create URLComponents or find query items.")
            return
        }
        print("ContentView processLaunchURL: URLComponents and query items found.")

        guard let huntTypeParam = queryItems.first(where: { $0.name == "hunt_type" })?.value,
              let huntType = HuntType(rawValue: huntTypeParam) else {
            print("ContentView processLaunchURL: No valid 'hunt_type' parameter found in URL query.")
            return
        }
        print("ContentView processLaunchURL: Hunt type parameter found: \(huntTypeParam)")
        
        guard let dataParam = queryItems.first(where: { $0.name == "data" })?.value else {
            print("ContentView processLaunchURL: No 'data' parameter found in URL query.")
            return
        }
        print("ContentView processLaunchURL: Data parameter found (length: \(dataParam.count)).")
        print("ContentView processLaunchURL: Found hunt_type: \(huntType.rawValue), data parameter: \(dataParam)")

        print("ContentView processLaunchURL: Attempting to decode base64 string...")
        guard let decodedData = Data(base64Encoded: dataParam) else {
            print("ContentView processLaunchURL: Failed to decode base64 string.")
            return
        }
        print("ContentView processLaunchURL: Successfully decoded base64 data (length: \(decodedData.count)).")

        let decoder = JSONDecoder()

        do {
            print("ContentView processLaunchURL: Attempting to decode JSON for hunt type: \(huntType.rawValue)")
            switch huntType {
            case .geolocation:
                let pinLocations = try decoder.decode([PinLocation].self, from: decodedData)
                self.objectLocations = pinLocations.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                self.proximityMarkers = [] // Clear proximity markers
                print("ContentView processLaunchURL: Successfully decoded Geolocation JSON: \(pinLocations.count) locations")
                print("ContentView processLaunchURL: Decoded Geolocation locations: \(self.objectLocations)")
                
                // Ensure an object type is selected if we received locations
                if !self.objectLocations.isEmpty && self.selectedObject == .none {
                    self.selectedObject = .coin // Default to coin if none selected
                    print("ContentView processLaunchURL: Defaulted selectedObject to .coin for geolocation.")
                }

            case .proximity:
                let markers = try decoder.decode([ProximityMarkerData].self, from: decodedData)
                self.proximityMarkers = markers
                self.objectLocations = [] // Clear geolocation locations
                print("ContentView processLaunchURL: Successfully decoded Proximity JSON: \(markers.count) markers")
                print("ContentView processLaunchURL: Decoded Proximity markers: \(self.proximityMarkers)")
                
                // For proximity, we'll use the Coin model as requested
                self.selectedObject = .coin
                print("ContentView processLaunchURL: Defaulted selectedObject to .coin for proximity.")
            }
            
            self.currentHuntType = huntType // Set the hunt type after successful decoding
            print("ContentView processLaunchURL: Set currentHuntType to \(huntType.rawValue)")
            print("ContentView processLaunchURL: JSON decoding successful.")

        } catch {
            print("ContentView processLaunchURL: Failed to decode JSON for \(huntType.rawValue): \(error)")
            // Handle decoding errors - maybe clear data and reset hunt type?
            self.objectLocations = []
            self.proximityMarkers = []
            self.currentHuntType = nil
            self.selectedObject = .none
            print("ContentView processLaunchURL: Cleared data and reset hunt type due to decoding error.")
        }
    }
}
