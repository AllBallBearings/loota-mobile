import Foundation
import CoreLocation
import CoreMotion
import Combine

struct SurveyDataPoint: Codable {
    let latitude: Double
    let longitude: Double
    let elevation: Double // in meters (GPS-based)
    let barometricElevation: Double? // in meters (pressure-based, more accurate for relative changes)
    let timestamp: Date
    let distanceFromStart: Double // in meters (cumulative distance traveled)
    let distanceFromOrigin: Double // in meters (straight-line distance from starting point)
    let segmentDistance: Double // in meters (distance from previous point)
}

class SurveyManager: ObservableObject {
    @Published var isActive = false
    @Published var dataPoints: [SurveyDataPoint] = []
    @Published var totalDistance: Double = 0.0 // in meters
    @Published var lastElevation: Double? = nil
    @Published var elapsedTime: TimeInterval = 0
    @Published var samplingInterval: SamplingInterval = .tenFeet
    
    private var locationManager: LocationManager?
    private var lastLocation: CLLocation?
    private var startLocation: CLLocation?
    private var startTime: Date?
    private var timer: Timer?
    private var samplingTimer: Timer?
    private var altimeter: CMAltimeter?
    private var baselineAltitude: Double?
    private var currentRelativeAltitude: Double?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum SamplingInterval: CaseIterable {
        case highPrecision
        case oneSecond
        case threeFeet
        case tenFeet
        
        var displayName: String {
            switch self {
            case .highPrecision: return "High Precision"
            case .oneSecond: return "1 second"
            case .threeFeet: return "3 feet"
            case .tenFeet: return "10 feet"
            }
        }
        
        var distanceInMeters: Double? {
            switch self {
            case .highPrecision: return 0.3048 // 1 foot in meters
            case .oneSecond: return nil // Time-based, not distance-based
            case .threeFeet: return 0.9144 // 3 feet in meters
            case .tenFeet: return 3.048   // 10 feet in meters
            }
        }
        
        var timeInterval: TimeInterval? {
            switch self {
            case .highPrecision: return nil // Distance-based, not time-based
            case .oneSecond: return 1.0 // 1 second
            case .threeFeet, .tenFeet: return nil // Distance-based, not time-based
            }
        }
    }
    
    var elapsedTimeString: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func startSurvey(locationManager: LocationManager) {
        guard !isActive else { return }
        
        self.locationManager = locationManager
        isActive = true
        
        // Only reset data if this is a completely new survey
        // Otherwise, continue from where we left off
        if dataPoints.isEmpty {
            totalDistance = 0.0
            lastLocation = nil
            startLocation = nil
            startTime = Date()
            elapsedTime = 0
        } else {
            // Resume from previous state but restart the timer
            startTime = Date().addingTimeInterval(-elapsedTime)
            // Set lastLocation to the location of the most recent data point
            if let lastDataPoint = dataPoints.last {
                lastLocation = CLLocation(latitude: lastDataPoint.latitude, longitude: lastDataPoint.longitude)
            }
            // Set startLocation from the first data point if resuming
            if let firstDataPoint = dataPoints.first {
                startLocation = CLLocation(latitude: firstDataPoint.latitude, longitude: firstDataPoint.longitude)
            }
        }
        
        // Start timer for elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        
        // Start altimeter for more accurate elevation tracking
        startAltimeterTracking()
        
        // Set up sampling based on interval type
        if let timeInterval = samplingInterval.timeInterval {
            // Time-based sampling
            samplingTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
                self?.recordCurrentLocation()
            }
            print("Survey started with time-based sampling: \(samplingInterval.displayName)")
        } else {
            // Distance-based sampling - subscribe to location updates
            locationManager.$currentLocation
                .compactMap { $0 }
                .sink { [weak self] location in
                    self?.processLocationUpdate(location)
                }
                .store(in: &cancellables)
            print("Survey started with distance-based sampling: \(samplingInterval.displayName)")
        }
    }
    
    func stopSurvey() {
        guard isActive else { return }
        
        isActive = false
        timer?.invalidate()
        timer = nil
        samplingTimer?.invalidate()
        samplingTimer = nil
        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil
        cancellables.removeAll()
        
        print("Survey stopped with \(dataPoints.count) data points")
    }
    
    func clearSurvey() {
        // Stop if currently active
        if isActive {
            stopSurvey()
        }
        
        // Clear all data
        dataPoints.removeAll()
        totalDistance = 0.0
        lastLocation = nil
        startLocation = nil
        lastElevation = nil
        elapsedTime = 0
        startTime = nil
        
        print("Survey data cleared")
    }
    
    private func processLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        guard isActive else { return }
        
        // We need to get the actual CLLocation from the LocationManager for proper altitude
        guard let locationManager = self.locationManager,
              let currentCLLocation = locationManager.currentCLLocation else { return }
        
        // For the first point, always record it
        if lastLocation == nil {
            recordDataPoint(withLocation: currentCLLocation)
            lastLocation = currentCLLocation
            return
        }
        
        guard let lastLoc = lastLocation else { return }
        
        let distance = currentCLLocation.distance(from: lastLoc)
        
        // Only record if we've moved at least the selected sampling interval distance
        if let distanceThreshold = samplingInterval.distanceInMeters, distance >= distanceThreshold {
            recordDataPoint(withLocation: currentCLLocation)
            lastLocation = currentCLLocation
            totalDistance += distance
        }
    }
    
    private func recordCurrentLocation() {
        guard isActive else { return }
        guard let locationManager = self.locationManager,
              let currentCLLocation = locationManager.currentCLLocation else { return }
        
        // For time-based sampling, always record the current location
        if let lastLoc = lastLocation {
            let distance = currentCLLocation.distance(from: lastLoc)
            totalDistance += distance
        }
        
        recordDataPoint(withLocation: currentCLLocation)
        lastLocation = currentCLLocation
    }
    
    private func recordDataPoint(withLocation location: CLLocation) {
        // Set start location for the first data point
        if startLocation == nil {
            startLocation = location
        }
        
        // Calculate various distance metrics
        let segmentDistance: Double
        if let lastLoc = lastLocation {
            segmentDistance = location.distance(from: lastLoc)
        } else {
            segmentDistance = 0.0
        }
        
        let distanceFromOrigin: Double
        if let startLoc = startLocation {
            distanceFromOrigin = location.distance(from: startLoc)
        } else {
            distanceFromOrigin = 0.0
        }
        
        // Use the actual altitude from Core Location if available and valid
        let gpsElevation = getValidElevation(from: location)
        
        // Try to get barometric altitude if available (iOS 15+)
        let barometricElevation = getBarometricElevation(from: location)
        
        let dataPoint = SurveyDataPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: gpsElevation,
            barometricElevation: barometricElevation,
            timestamp: Date(),
            distanceFromStart: self.totalDistance,
            distanceFromOrigin: distanceFromOrigin,
            segmentDistance: segmentDistance
        )
        
        self.dataPoints.append(dataPoint)
        self.lastElevation = barometricElevation ?? gpsElevation
        
        print("Recorded data point: \(dataPoint.latitude), \(dataPoint.longitude), GPS elevation: \(gpsElevation)m, barometric: \(barometricElevation?.description ?? "N/A")m, distance from origin: \(distanceFromOrigin)m, interval: \(samplingInterval.displayName)")
    }
    
    private func getValidElevation(from location: CLLocation) -> Double {
        // Check if we have valid altitude data from Core Location
        // verticalAccuracy < 0 means invalid data
        // altitude values that are unreasonably large are likely invalid
        if location.verticalAccuracy >= 0 && location.verticalAccuracy < 50 && abs(location.altitude) < 10000 {
            return location.altitude
        }
        
        // If we don't have valid Core Location altitude, we could integrate with an elevation service
        // For now, return 0 to indicate unknown elevation rather than random values
        print("⚠️ Invalid or unavailable altitude data (accuracy: \(location.verticalAccuracy)m, altitude: \(location.altitude)m)")
        return 0.0
    }
    
    private func getBarometricElevation(from location: CLLocation) -> Double? {
        // Use CMAltimeter data if available (more accurate for relative changes)
        if let relativeAltitude = currentRelativeAltitude {
            return relativeAltitude
        }
        
        // Try to access barometric altitude if available (iOS 15.0+)
        if #available(iOS 15.0, *) {
            // Check if the location has ellipsoidal altitude which might be more accurate
            if location.ellipsoidalAltitude != CLLocationDistanceMax {
                return location.ellipsoidalAltitude
            }
        }
        
        // No barometric data available
        return nil
    }
    
    private func startAltimeterTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("⚠️ Altimeter not available on this device")
            return
        }
        
        altimeter = CMAltimeter()
        altimeter?.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] (altitudeData, error) in
            if let error = error {
                print("⚠️ Altimeter error: \(error.localizedDescription)")
                return
            }
            
            guard let altitudeData = altitudeData else { return }
            
            // Store baseline altitude for the first reading
            if self?.baselineAltitude == nil {
                self?.baselineAltitude = altitudeData.relativeAltitude.doubleValue
                self?.currentRelativeAltitude = 0.0
                print("📏 Altimeter baseline set: \(altitudeData.relativeAltitude.doubleValue)m")
            } else if let baseline = self?.baselineAltitude {
                // Calculate relative altitude change from the start
                self?.currentRelativeAltitude = altitudeData.relativeAltitude.doubleValue - baseline
                print("📏 Relative altitude: \(self?.currentRelativeAltitude ?? 0.0)m")
            }
        }
        
        print("📏 Started altimeter tracking for better elevation accuracy")
    }
    
    func exportAsCSV() -> String {
        guard !dataPoints.isEmpty else { return "No data to export" }
        
        var csvString = "Index,Latitude,Longitude,GPS_Elevation_m,GPS_Elevation_ft,Barometric_Elevation_m,Barometric_Elevation_ft,Timestamp,Distance_Traveled_m,Distance_Traveled_ft,Distance_From_Origin_m,Distance_From_Origin_ft,Segment_Distance_m,Segment_Distance_ft\n"
        
        for (index, point) in dataPoints.enumerated() {
            let gpsElevationFt = point.elevation * 3.28084
            let barometricElevationFt = (point.barometricElevation ?? 0) * 3.28084
            let distanceTraveledFt = point.distanceFromStart * 3.28084
            let distanceFromOriginFt = point.distanceFromOrigin * 3.28084
            let segmentDistanceFt = point.segmentDistance * 3.28084
            let timeString = ISO8601DateFormatter().string(from: point.timestamp)
            
            csvString += "\(index + 1),\(point.latitude),\(point.longitude),\(point.elevation),\(gpsElevationFt),\(point.barometricElevation?.description ?? ""),\(point.barometricElevation != nil ? String(barometricElevationFt) : ""),\(timeString),\(point.distanceFromStart),\(distanceTraveledFt),\(point.distanceFromOrigin),\(distanceFromOriginFt),\(point.segmentDistance),\(segmentDistanceFt)\n"
        }
        
        return csvString
    }
    
    func exportAsJSON() -> String {
        guard !dataPoints.isEmpty else { return "No data to export" }
        
        let exportData = SurveyExportData(
            surveyInfo: SurveyInfo(
                totalPoints: dataPoints.count,
                totalDistance: totalDistance,
                totalDistanceFt: totalDistance * 3.28084,
                duration: elapsedTime,
                startTime: startTime ?? Date(),
                endTime: Date()
            ),
            dataPoints: dataPoints
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(exportData)
            return String(data: jsonData, encoding: .utf8) ?? "Failed to encode JSON"
        } catch {
            return "Error encoding JSON: \(error.localizedDescription)"
        }
    }
}

struct SurveyExportData: Codable {
    let surveyInfo: SurveyInfo
    let dataPoints: [SurveyDataPoint]
}

struct SurveyInfo: Codable {
    let totalPoints: Int
    let totalDistance: Double // meters
    let totalDistanceFt: Double // feet
    let duration: TimeInterval // seconds
    let startTime: Date
    let endTime: Date
}