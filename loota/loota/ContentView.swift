// ContentView.swift

import SwiftUI
import CoreLocation

enum ARObjectType: String, CaseIterable, Identifiable {
    case none = "None"
    case coin = "Coin"
    case dollarSign = "Dollar Sign"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var coinsCollected: Int = 0
    @State private var animate: Bool = false
    @State private var selectedObject: ARObjectType = .none
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var objectLocations: [CLLocationCoordinate2D] = [] // Changed to array
    @StateObject private var locationManager = LocationManager()
    
    // Helper struct for JSON decoding
    struct PinLocation: Codable {
        let lat: Double
        let lng: Double
    }
    
    var body: some View {
        ZStack {
            // Main container ZStack
            // AR View in the background
            if selectedObject != .none && !objectLocations.isEmpty { // Check if locations array is not empty
                ARViewContainer(
                    objectLocations: $objectLocations, // Pass array binding
                    referenceLocation: $locationManager.currentLocation,
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
                    objectType: selectedObject
                )
                .id(selectedObject) // Recreate only when object type changes
                .edgesIgnoringSafeArea(.all)
            } else {
                 // Placeholder when no object is selected
                 Color.gray.edgesIgnoringSafeArea(.all)
                 Text("Select an object type")
                     .foregroundColor(.white)
                     .font(.title)
            }

            // UI Overlay VStack
            VStack {
                // Top Row: Counter and Picker
                HStack(alignment: .top) {
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

                    Spacer() // Pushes picker to the right

                    // Picker for object type
                    Picker("Object", selection: $selectedObject) {
                        ForEach(ARObjectType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .frame(maxWidth: 250) // Limit picker width
                    .padding([.top, .trailing], 16)
                }
                .padding(.bottom, 20) // Add padding below top controls

                Spacer() // Pushes sliders to bottom/right

                // GPS Coordinates Display
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
                    
                    Text("Object Locations (\(objectLocations.count)):") // Show count
                        .font(.headline)
                        .foregroundColor(.white)
                    // Optionally display the first object's location or just the count
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
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .padding()
            }
        }
        .onChange(of: selectedObject) { newValue in
            // Clear locations when object type changes to none.
            // Locations are now only set via launch argument/URL parsing.
            if newValue == .none {
                 objectLocations = []
                 print("Object type set to None, clearing locations.")
            }
            // We no longer set a hardcoded location here.
        }
        .onReceive(locationManager.$currentLocation) { location in
            currentLocation = location
        }
        .onAppear {
            locationManager.requestAuthorization()
            
            // For simplicity, we'll focus on location functionality
            // and remove the URL handling for now
            locationManager.startUpdating()

            // Check for launch arguments
            let arguments = ProcessInfo.processInfo.arguments
            if let urlIndex = arguments.firstIndex(of: "-appLaunchURL"), urlIndex + 1 < arguments.count {
                let urlString = arguments[urlIndex + 1]
                if let url = URL(string: urlString) {
                    print("Received launch argument URL: \(url)")
                    parsePinsFromURL(url)
                } else {
                    print("Failed to create URL from launch argument: \(urlString)")
                }
            }
        }
        // .onOpenURL can be added back later if needed for real URL launches
        // .onOpenURL { url in
        //     print("Received URL via onOpenURL: \(url)")
        //     parsePinsFromURL(url)
        // }
    }

    func parsePinsFromURL(_ url: URL) {
        print("Attempting to parse URL: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true), // Use true for file URLs
              let queryItems = components.queryItems else {
            print("Could not create URLComponents or find query items.")
            return
        }

        guard let pinsParam = queryItems.first(where: { $0.name == "pins" })?.value else {
            print("No 'pins' parameter found in URL query.")
            return
        }
        print("Found pins parameter: \(pinsParam)")

        guard let decodedData = Data(base64Encoded: pinsParam) else {
            print("Failed to decode base64 string.")
            return
        }
        print("Successfully decoded base64 data.")

        do {
            let decoder = JSONDecoder()
            let pinLocations = try decoder.decode([PinLocation].self, from: decodedData)
            print("Successfully decoded JSON: \(pinLocations.count) locations")
            
            // Convert decoded structs to CLLocationCoordinate2D and update state
            self.objectLocations = pinLocations.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            print("Updated objectLocations state with \(self.objectLocations.count) coordinates.")
            
            // Ensure an object type is selected if we received locations
            if !self.objectLocations.isEmpty && self.selectedObject == .none {
                self.selectedObject = .coin // Default to coin if none selected
                print("Defaulted selectedObject to .coin")
            }
            
        } catch {
            print("Failed to decode JSON: \(error)")
            // Attempt fallback for single coordinate format (lat,lng)
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                 let coordinates = decodedString.components(separatedBy: ",")
                 if coordinates.count == 2,
                    let latitude = Double(coordinates[0]),
                    let longitude = Double(coordinates[1]) {
                     self.objectLocations = [CLLocationCoordinate2D(latitude: latitude, longitude: longitude)]
                     print("Fallback: Parsed single coordinate: \(latitude), \(longitude)")
                     if self.selectedObject == .none { self.selectedObject = .coin }
                 } else {
                     print("Fallback failed: Invalid single coordinate format.")
                 }
            } else {
                 print("Fallback failed: Could not decode data as UTF8 string.")
            }
        }
    }
}
