// MapView.swift

import SwiftUI
import MapKit
import CoreLocation // Import CoreLocation

// Simple identifiable struct for map annotations
struct MapPin: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

// Observable class to manage location services
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var isAuthorized: Bool = false // Simplified authorization check

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // High accuracy needed for AR placement
        // manager.requestWhenInUseAuthorization() // Request moved to MapView.onAppear
        // Note: You MUST add NSLocationWhenInUseUsageDescription to your Info.plist

        // Check initial status in case it was already determined
        self.locationManagerDidChangeAuthorization(manager)
    }

    // Public method to request authorization, called from View
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
        print("Explicitly requesting When In Use authorization.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation() // Start getting location updates
            print("Location authorized.")
        case .restricted, .denied:
            isAuthorized = false
            print("Location restricted or denied.")
        case .notDetermined:
            isAuthorized = false
            print("Location authorization not determined.")
            // It's generally better to request authorization explicitly from the view's onAppear
            // manager.requestWhenInUseAuthorization() // Avoid re-requesting here automatically
        @unknown default:
            isAuthorized = false
            print("Unknown location authorization status.")
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last // Get the latest location
        // Optional: Stop updates if you only need one location fix?
        // manager.stopUpdatingLocation()
        print("Location updated: \(userLocation?.coordinate ?? CLLocationCoordinate2D())")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        // Handle errors appropriately, e.g., inform the user
    }
}


struct MapView: View {
    @Binding var pinLocations: [CLLocationCoordinate2D] // Receive from ContentView
    @StateObject private var locationManager = LocationManager() // Manage location
    @Environment(\.dismiss) var dismiss // To close the sheet

    // State for the map's region and the pins displayed on the map
    // Use a smaller span for higher initial zoom (e.g., 0.002)
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default (SF)
        span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002) // Higher zoom
    )
    @State private var mapPins: [MapPin] = [] // Pins currently shown on map

    var body: some View {
        NavigationView { // Use NavigationView for title and buttons
            VStack {
                // Check the specific authorization status
                switch locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    // Map View when authorized
                    MapReader { proxy in // Keep MapReader in case we revisit conversion
                        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapPins) { pin in
                            // Display pins on the map
                            MapAnnotation(coordinate: pin.coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                    .background(Circle().fill(.white).opacity(0.7))
                            }
                        }
                        // Revert to Tap Gesture directly on Map, using 5m North offset logic
                        .onTapGesture {
                            print("Map tapped.")
                            // Add pin offset from CURRENT USER location, not map center
                            if let userLocation = locationManager.userLocation {
                                let metersNorth: Double = 5.0 // Place pin 5 meters North
                                let earthRadius: Double = 6371000.0 // Approx Earth radius in meters

                                let currentCoord = userLocation.coordinate
                                let latRadians = currentCoord.latitude * .pi / 180.0

                                // Calculate new latitude
                                let latitudeOffset = (metersNorth / earthRadius) * (180.0 / .pi)
                                let newLatitude = currentCoord.latitude + latitudeOffset

                                // Calculate new longitude (offset is 0 for Northward movement)
                                let newLongitude = currentCoord.longitude // No East/West offset here

                                let offsetCoord = CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)

                                let newPin = MapPin(coordinate: offsetCoord)
                                mapPins.append(newPin)
                                print("Pin added 5m North of user: \(offsetCoord.latitude), \(offsetCoord.longitude). Total: \(mapPins.count)")

                            } else {
                                print("Cannot add pin: User location not available at time of tap.")
                            }
                        }
                        .onChange(of: locationManager.userLocation) { newUserLocation in
                            // Center map only once when location first becomes available
                            // and if the user hasn't already panned/zoomed significantly
                            // or if no pins are placed yet.
                            if let location = newUserLocation, mapPins.isEmpty {
                                // Check if the region center is still the default or very close to it
                                let defaultCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                let distance = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                                    .distance(from: CLLocation(latitude: defaultCenter.latitude, longitude: defaultCenter.longitude))

                                if distance < 1000 { // Only auto-center if map hasn't been moved much from default
                                     region.center = location.coordinate
                                     print("Map centered on initial user location.")
                                }
                            }
                        }
                    } // End MapReader
                case .denied, .restricted:
                    // Message for denied or restricted access
                    Text("Location access has been denied or restricted. Please enable 'While Using the App' access for Loota in the Settings app.")
                        .padding()
                        .multilineTextAlignment(.center)
                case .notDetermined:
                    // Message while waiting for user decision
                    Text("Requesting location access...")
                        .padding()
                default:
                    // Fallback message (includes nil status initially)
                    Text("Checking location status...")
                        .padding()
                }
            } // End VStack
            .navigationTitle("Place Objects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        mapPins.removeAll() // Clear pins from the map
                        print("Map pins cleared.")
                    }
                    .disabled(mapPins.isEmpty) // Disable if no pins
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Update the binding with the final pin locations
                        pinLocations = mapPins.map { $0.coordinate }
                        print("Saving \(pinLocations.count) pin locations.")
                        dismiss() // Close the modal sheet
                    }
                }
            }
            .onAppear {
                // Initialize mapPins from the binding when the view appears
                mapPins = pinLocations.map { MapPin(coordinate: $0) }
                print("MapView appeared with \(mapPins.count) initial pins.")

                // Request authorization when the view appears if status is not determined
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestAuthorization()
                }

                // Attempt to center on user location if already available and authorized
                // (Logic moved to .onChange for better timing)
            }
        }
    }
}

// Preview Provider (Optional)
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy binding for the preview
        MapView(pinLocations: .constant([
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4184)
        ]))
    }
}
