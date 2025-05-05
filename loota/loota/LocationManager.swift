import CoreLocation

class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()
    private let meterPerDegree: Double = 111320.0 // Meters per degree at equator
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
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
        if manager.authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        } else {
            print("❌ Location authorization denied or not determined")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: $error.localizedDescription)")
    }
}
