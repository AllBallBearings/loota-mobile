import CoreLocation

class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var heading: CLHeading? {
            didSet {
                print("🧭 Heading updated: \(heading?.trueHeading ?? -1)")
            }
        }
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
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingHeading()
            }
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
