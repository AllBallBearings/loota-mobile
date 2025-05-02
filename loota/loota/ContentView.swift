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
    @State private var objectLocation: CLLocationCoordinate2D?
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            // Main container ZStack
            // AR View in the background
            if selectedObject != .none {
                ARViewContainer(
                    objectLocation: $objectLocation,
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
                    
                    Text("Object Location:")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(String(format: "%.6f", objectLocation?.latitude ?? 0))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                    Text(String(format: "%.6f", objectLocation?.longitude ?? 0))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .padding()
            }
        }
        .onChange(of: selectedObject) { newValue in
            if newValue != .none {
                // Set hardcoded coordinates for testing
                objectLocation = CLLocationCoordinate2D(
                    latitude: 35.67226767113417,
                    longitude: -78.75162204749381
                )
            }
        }
        .onReceive(locationManager.$currentLocation) { location in
            currentLocation = location
        }
        .onAppear {
            locationManager.requestAuthorization()
            
            // For simplicity, we'll focus on location functionality
            // and remove the URL handling for now
            locationManager.startUpdating()
        }
        .onOpenURL { url in
            print("Received URL: \(url)")
            parsePinsFromURL(url)
        }
    }
    
    func parsePinsFromURL(_ url: URL) {
        // Extract query items from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("No query items found in URL")
            return
        }
        
        // Find the "pins" parameter
        let pinsItem = queryItems.first { $0.name == "pins" }
        guard let pinsData = pinsItem?.value else {
            print("No 'pins' parameter found in URL")
            return
        }
        
        // Decode base64 data
        guard let decodedData = Data(base64Encoded: pinsData),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            print("Failed to decode base64 'pins' parameter")
            return
        }
        
        // Split into latitude and longitude
        let coordinates = decodedString.components(separatedBy: ",")
        guard coordinates.count == 2,
              let latitude = Double(coordinates[0]),
              let longitude = Double(coordinates[1]) else {
            print("Invalid coordinate format in 'pins' parameter")
            return
        }
        
        // Update object location and log coordinates
        objectLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        print("Extracted coordinates: \(latitude), \(longitude)")
    }
}
