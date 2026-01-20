import CoreLocation

class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var heading: CLHeading? {
        didSet {
            print("🧭 Heading updated: \(heading?.trueHeading ?? -1), Accuracy: \(heading?.headingAccuracy ?? -1)")
            // Update formatted strings when heading changes
            if let h = heading {
                if h.trueHeading >= 0 {
                    self.trueHeadingString = String(format: "Heading: %.2f°", h.trueHeading)
                } else {
                    self.trueHeadingString = "Heading: Invalid"
                }
                if h.headingAccuracy >= 0 {
                    self.accuracyString = String(format: "Accuracy: %.2f°", h.headingAccuracy)
                } else {
                    self.accuracyString = "Accuracy: Invalid"
                }
            } else {
                self.trueHeadingString = "Heading: N/A"
                self.accuracyString = "Accuracy: N/A"
            }
        }
    }
    @Published var trueHeadingString: String = "Heading: N/A"
    @Published var accuracyString: String = "Accuracy: N/A"
    
    private let locationManager = CLLocationManager()
    private let meterPerDegree: Double = 111320.0 // Meters per degree at equator
    
    override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.headingFilter = kCLHeadingFilterNone
        }
        
        func requestAuthorization() {
            locationManager.requestWhenInUseAuthorization()
        }
        
        func startUpdating() {
            // Start location updates directly - authorization is already checked
            // by the caller (locationManagerDidChangeAuthorization)
            // Note: Avoid calling CLLocationManager.locationServicesEnabled() on main thread
            // as it can cause UI unresponsiveness
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        print("📍 Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        #if os(iOS)
        if manager.authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        } else {
            print("❌ Location authorization denied or not determined")
        }
        #elseif os(macOS)
        // Handle macOS authorization if needed, or just print status
        if manager.authorizationStatus == .authorizedAlways { // macOS uses .authorizedAlways or similar
            startUpdating()
        } else {
            print("❌ Location authorization denied or not determined for macOS")
        }
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
    }

    // Add the missing delegate method for heading updates
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
        // The print statement is already in the `didSet` of the `heading` property,
        // so we don't strictly need another one here unless for more specific debugging.
        // print("🧭 Delegate received heading: \(newHeading.trueHeading)")
    }
}
