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
    @State private var statusMessage: String = "" // Add status message state
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
            let _ = print("ContentView body: selectedObject = \(selectedObject.rawValue), objectLocations.count = \(objectLocations.count), refLocation = \(String(describing: locationManager.currentLocation)), heading = \(String(describing: locationManager.heading?.trueHeading))")
            if selectedObject != .none && !objectLocations.isEmpty { // Check if locations array is not empty
                let _ = print("ContentView: ARViewContainer WILL be created.")
                ARViewContainer(
                    objectLocations: $objectLocations, // Pass array binding
                    referenceLocation: $locationManager.currentLocation,
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
                    objectType: $selectedObject // Use $ to pass the binding
                )
                .id(selectedObject) // Recreate only when object type changes
                .edgesIgnoringSafeArea(.all)
            } else {
                 // Placeholder when no object is selected
                 Color.gray.edgesIgnoringSafeArea(.all)
                 Text("Select an object type (or provide object locations)")
                     .foregroundColor(.white)
                     .font(.title)
                 let _ = print("ContentView: ARViewContainer WILL NOT be created. selectedObject: \(selectedObject.rawValue), objectLocations.isEmpty: \(objectLocations.isEmpty)")
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
                    
                    // Status message display
                    Text(statusMessage)
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(.top, 8)
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
                 print("ContentView onChange selectedObject: \(newValue.rawValue) - Object type set to None, clearing locations.")
            } else {
                print("ContentView onChange selectedObject: \(newValue.rawValue)")
            }
            // We no longer set a hardcoded location here.
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
            
            // For simplicity, we'll focus on location functionality
            // and remove the URL handling for now
            locationManager.startUpdating()

            // Check for launch arguments
            let arguments = ProcessInfo.processInfo.arguments
            if let urlIndex = arguments.firstIndex(of: "-appLaunchURL"), urlIndex + 1 < arguments.count {
                let urlString = arguments[urlIndex + 1]
                if let url = URL(string: urlString) {
                    print("ContentView onAppear: Received launch argument URL: \(url)")
                    parsePinsFromURL(url)
                } else {
                    print("ContentView onAppear: Failed to create URL from launch argument: \(urlString)")
                }
            } else {
                print("ContentView onAppear: No -appLaunchURL argument found.")
            }
            print("ContentView onAppear: objectLocations.count = \(objectLocations.count), selectedObject = \(selectedObject.rawValue)")
        }
        // .onOpenURL can be added back later if needed for real URL launches
        // .onOpenURL { url in
        //     print("Received URL via onOpenURL: \(url)")
        //     parsePinsFromURL(url)
        // }
    }

    func parsePinsFromURL(_ url: URL) {
        print("ContentView parsePinsFromURL: Attempting to parse URL: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true), // Use true for file URLs
              let queryItems = components.queryItems else {
            print("ContentView parsePinsFromURL: Could not create URLComponents or find query items.")
            return
        }

        guard let pinsParam = queryItems.first(where: { $0.name == "pins" })?.value else {
            print("ContentView parsePinsFromURL: No 'pins' parameter found in URL query.")
            return
        }
        print("ContentView parsePinsFromURL: Found pins parameter: \(pinsParam)")

        guard let decodedData = Data(base64Encoded: pinsParam) else {
            print("ContentView parsePinsFromURL: Failed to decode base64 string.")
            return
        }
        print("ContentView parsePinsFromURL: Successfully decoded base64 data.")

        do {
            let decoder = JSONDecoder()
            let pinLocations = try decoder.decode([PinLocation].self, from: decodedData)
            print("ContentView parsePinsFromURL: Successfully decoded JSON: \(pinLocations.count) locations")
            
            // Convert decoded structs to CLLocationCoordinate2D and update state
            self.objectLocations = pinLocations.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            print("ContentView parsePinsFromURL: Updated objectLocations state with \(self.objectLocations.count) coordinates.")
            
            // Ensure an object type is selected if we received locations
            if !self.objectLocations.isEmpty && self.selectedObject == .none {
                self.selectedObject = .coin // Default to coin if none selected
                print("ContentView parsePinsFromURL: Defaulted selectedObject to .coin")
            }
            
        } catch {
            print("ContentView parsePinsFromURL: Failed to decode JSON: \(error)")
            // Attempt fallback for single coordinate format (lat,lng)
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                 let coordinates = decodedString.components(separatedBy: ",")
                 if coordinates.count == 2,
                    let latitude = Double(coordinates[0]),
                    let longitude = Double(coordinates[1]) {
                     self.objectLocations = [CLLocationCoordinate2D(latitude: latitude, longitude: longitude)]
                     print("ContentView parsePinsFromURL: Fallback: Parsed single coordinate: \(latitude), \(longitude)")
                     if self.selectedObject == .none { self.selectedObject = .coin }
                 } else {
                     print("ContentView parsePinsFromURL: Fallback failed: Invalid single coordinate format.")
                 }
            } else {
                 print("ContentView parsePinsFromURL: Fallback failed: Could not decode data as UTF8 string.")
            }
        }
    }
}
