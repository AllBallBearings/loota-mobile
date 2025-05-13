// ARViewContainer.swift

import SwiftUI
import ARKit
import RealityKit
import CoreLocation
import AVFoundation
import Combine // Import Combine for sink

extension CLLocationDirection {
    var degreesToRadians: Double { return self * .pi / 180 }
}

import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var objectLocations: [CLLocationCoordinate2D] // Changed to array
    var referenceLocation: CLLocationCoordinate2D? // Changed back to var
    @Binding var statusMessage: String // Add status message binding
    @Binding var heading: CLHeading? // Add heading binding
    var onCoinCollected: (() -> Void)?
    @Binding var objectType: ARObjectType // Changed to @Binding
    @Binding var currentHuntType: HuntType? // Add new binding for hunt type
    @Binding var proximityMarkers: [ProximityMarkerData] // Add new binding for proximity data

    // Correct initializer signature
    public init(objectLocations: Binding<[CLLocationCoordinate2D]>,
               referenceLocation: CLLocationCoordinate2D?, // Changed back to non-Binding
               statusMessage: Binding<String>, // Add status message binding
               heading: Binding<CLHeading?>, // Add heading binding
               onCoinCollected: (() -> Void)? = nil,
               objectType: Binding<ARObjectType>, // Changed to Binding<ARObjectType>
               currentHuntType: Binding<HuntType?>, // Add new parameter
               proximityMarkers: Binding<[ProximityMarkerData]>) { // Add new parameter
        print("ARViewContainer init: objectType=\(objectType.wrappedValue.rawValue), objectLocations.count=\(objectLocations.wrappedValue.count), refLocation=\(String(describing: referenceLocation)), heading=\(String(describing: heading.wrappedValue?.trueHeading)), huntType=\(String(describing: currentHuntType.wrappedValue)), proximityMarkers.count=\(proximityMarkers.wrappedValue.count))")
        self._objectLocations = objectLocations
        self.referenceLocation = referenceLocation // Assign direct value
        self._statusMessage = statusMessage
        self._heading = heading // Assign heading binding
        self.onCoinCollected = onCoinCollected
        self._objectType = objectType // Changed to assign to _objectType
        self._currentHuntType = currentHuntType // Assign new binding
        self._proximityMarkers = proximityMarkers // Assign new binding
    }

    // GPS conversion constants are now in Coordinator

    // MARK: - UIViewRepresentable Methods

    func makeUIView(context: Context) -> ARView {
        print("ARViewContainer makeUIView called.")
        // Reset alignment flag for debugging, to ensure alignment is attempted each time view is made
        // context.coordinator.hasAlignedToNorth = false // Potentially problematic if coordinator is reused; better to do this in init if needed
        // For now, let&#x27;s rely on the Coordinator&#x27;s own initialization of hasAlignedToNorth = false

        let arView = ARView(frame: .zero)

        // Configure AR session for world tracking
        let worldConfig = ARWorldTrackingConfiguration()
        worldConfig.environmentTexturing = .automatic
        worldConfig.planeDetection = [.horizontal, .vertical] // Keep plane detection if needed

        // Assign the coordinator as the session delegate *before* running
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView // Assign weak reference

        arView.session.run(worldConfig, options: [])

        // Setup display link for animations
        let displayLink = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.updateRotation))
        displayLink.add(to: .main, forMode: .default)

        // Assign callbacks and initial properties to coordinator
        context.coordinator.onCoinCollected = self.onCoinCollected
        context.coordinator.revolutionDuration = 1.5 // Example duration
        
        // The Coordinator is initialized with all necessary bindings and actions in makeCoordinator().
        // Re-assigning them in makeUIView is generally redundant.
        // placeObjectsAction is set in makeCoordinator and captures the necessary bindings.

        // Initial placement of objects will now be triggered by the heading observer in the coordinator
        // Replaced updateObjectPlacement with a direct call to the coordinator's method
        context.coordinator.placeObjectsInARView(arView: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("ARViewContainer updateUIView: Called. Struct's refLoc=\(String(describing: referenceLocation)), Struct's heading=\(String(describing: heading?.trueHeading))")
        // Explicitly update Coordinator's copy of referenceLocation if it changed in the struct's binding
        if context.coordinator.referenceLocation?.latitude != self.referenceLocation?.latitude || context.coordinator.referenceLocation?.longitude != self.referenceLocation?.longitude {
            context.coordinator.referenceLocation = self.referenceLocation
            print("ARViewContainer updateUIView: Updated coordinator.referenceLocation to \(String(describing: self.referenceLocation))")
        }
        print("ARViewContainer updateUIView: Coordinator's refLoc after potential update=\(String(describing: context.coordinator.referenceLocation)), Coord's heading=\(String(describing: context.coordinator.heading?.trueHeading))")
        
        context.coordinator.onCoinCollected = self.onCoinCollected
        
let oldCoordHeading = context.coordinator.heading?.trueHeading
let newStructHeading = self.heading?.trueHeading
if oldCoordHeading != newStructHeading {
    context.coordinator.heading = self.heading
    print("ARViewContainer updateUIView: Updated coordinator.heading to \(String(describing: newStructHeading))")
}

        context.coordinator.attemptPlacementIfReady()
        
        // beyond what @Binding provides, that would be handled here or via Combine publishers.
        // For now, the Coordinator's heading.didSet is the main trigger for initial placement.
        // Force initial placement if heading is already available
        if let heading = self.heading {
            context.coordinator.heading = heading
        }
    }

    func makeCoordinator() -> Coordinator {
        // Initialize coordinator with the initial wrapped value of referenceLocation
        let coordinator = Coordinator(
            initialReferenceLocation: self.referenceLocation, // Pass direct value
            objectLocations: $objectLocations,
            objectType: $objectType,
            statusMessage: $statusMessage,
            currentHuntType: $currentHuntType, // Pass binding
            proximityMarkers: $proximityMarkers  // Pass binding
        )
        // Set the placeObjectsAction on the newly created coordinator instance
        // The coordinator&#x27;s placeObjectsAction will call its own placeObjectsInARView method.
        coordinator.placeObjectsAction = coordinator.placeObjectsInARView 
        return coordinator
    }
    
    // placeObjects, createEntity, convertToARWorldCoordinate are now moved to Coordinator

    // MARK: - Coordinator Class

    class Coordinator: NSObject, ARSessionDelegate {
        // referenceLocation is now a simple var, updated by ARViewContainer.updateUIView
        var referenceLocation: CLLocationCoordinate2D?
        // These remain bindings
        @Binding var objectLocations: [CLLocationCoordinate2D]
        @Binding var objectType: ARObjectType
        @Binding var statusMessage: String
        @Binding var currentHuntType: HuntType? // Added binding
        @Binding var proximityMarkers: [ProximityMarkerData] // Added binding
        // Removed the redundant @Binding for heading here. We use the simple var heading below.

        var onCoinCollected: (() -> Void)?
        var coinEntities: [ModelEntity] = []
        var anchors: [AnchorEntity] = []
        var revolutionDuration: TimeInterval = 1.5
        var accumulatedAngle: Float = 0
        var lastTimestamp: CFTimeInterval?
        weak var arView: ARView?
        var audioPlayer: AVAudioPlayer? // Moved audio player here
        
        // Base anchor for world alignment
        var baseAnchor: AnchorEntity?
        
        // Action to trigger object placement from the Coordinator
        var placeObjectsAction: ((ARView?) -> Void)? // This will be set to self.placeObjectsInARView

        // Properties for heading alignment
        var heading: CLHeading? { // Observe heading changes
            didSet {
                print("Coordinator heading.didSet: New heading: \(String(describing: heading?.trueHeading)), Old heading: \(String(describing: oldValue?.trueHeading)), hasAlignedToNorth: \(hasAlignedToNorth)")
                // Only attempt alignment once and if we have a valid heading and arView
                if !hasAlignedToNorth, let trueHeading = heading?.trueHeading, let arView = arView {
                    print("Coordinator heading.didSet: Conditions MET for alignment. Aligning and placing.")
                    alignARWorldToNorth(arView: arView, heading: trueHeading)
                    hasAlignedToNorth = true // Set flag after first alignment attempt
                    
                    // Now that we have heading and base anchor is potentially rotated, place objects
                    // Alignment is done. Placement will be attempted via attemptPlacementIfReady,
                    // which is also called from updateUIView.
                    print("Coordinator heading.didSet: Alignment complete. hasAlignedToNorth is now true.")
                    // No direct call to attemptPlacementIfReady here; let updateUIView handle it
                    // to ensure referenceLocation has potentially updated too.
                } else {
                    print("Coordinator heading.didSet: Conditions NOT MET for alignment. hasAlignedToNorth=\(hasAlignedToNorth), trueHeading=\(String(describing: heading?.trueHeading)), arView is nil=\(arView == nil)")
                }
            }
        }
        private var hasAlignedToNorth = false // Track if we've aligned to north
        private var hasPlacedObjects = false // New flag to ensure placement happens only once

        // Combine cancellables for observing changes
        private var cancellables: Set<AnyCancellable> = []
        
        // GPS conversion constants
        private let metersPerDegree: Double = 111319.5

        // Initializer - receives initial referenceLocation value and other bindings
        init(initialReferenceLocation: CLLocationCoordinate2D?, // Changed from Binding
             objectLocations: Binding<[CLLocationCoordinate2D]>,
             objectType: Binding<ARObjectType>,
             statusMessage: Binding<String>,
             currentHuntType: Binding<HuntType?>, // Added parameter
             proximityMarkers: Binding<[ProximityMarkerData]>) { // Added parameter
            print("Coordinator init: Setting up.")
            self.referenceLocation = initialReferenceLocation // Assign initial value
            self._objectLocations = objectLocations
            self._objectType = objectType
            self._statusMessage = statusMessage
            self._currentHuntType = currentHuntType // Assign binding
            self._proximityMarkers = proximityMarkers // Assign binding
            
            // Removed problematic referenceLocationObserver
            
            super.init()
            print("Coordinator init: Initial referenceLocation = \(String(describing: initialReferenceLocation)))")
        }
        
        // Helper function for degree to radian conversion
        static func degreesToRadians(_ degrees: Double) -> Double {
            return degrees * .pi / 180.0
        }

        func attemptPlacementIfReady() {
            print("Coordinator attemptPlacementIfReady: Checking conditions. hasAlignedToNorth=\(hasAlignedToNorth), referenceLocationIsNil=\(self.referenceLocation == nil), hasPlacedObjects=\(hasPlacedObjects), arViewIsNil=\(self.arView == nil)")
            guard hasAlignedToNorth, self.referenceLocation != nil, !hasPlacedObjects, let arView = self.arView else {
                print("Coordinator attemptPlacementIfReady: Conditions not met or already placed.")
                return
            }
            
            // Force placement if we have a valid reference location
            if self.referenceLocation != nil {
                self.placeObjectsAction?(arView)
                self.hasPlacedObjects = true
            }
            
            print("Coordinator attemptPlacementIfReady: All conditions MET. Calling placeObjectsAction.")
            self.placeObjectsAction?(arView) // This will call placeObjectsInARView
            self.hasPlacedObjects = true // Mark as placed
        }

        // Wrapper function to match the expected signature for placeObjectsAction
        func placeObjectsInARView(arView: ARView?) {
            guard let arView = arView else {
                print("Coordinator placeObjectsInARView: arView is nil.")
                return
            }
            // Now call the main placement logic, using the Coordinator's own bindings
            self.placeObjects(arView: arView)
        }

        // Main object placement logic, now using Coordinator's bindings
        private func placeObjects(arView: ARView) {
            print("Coordinator placeObjects: Checking referenceLocation. Current referenceLocation = \(String(describing: self.referenceLocation))")
            guard let refLoc = self.referenceLocation else {
                print("Coordinator placeObjects: Guard FAILED - self.referenceLocation is nil.")
                return
            }

            self.clearAnchors()

            var newEntities: [ModelEntity] = []
            var newAnchors: [AnchorEntity] = []

            // Check the hunt type
            switch self.currentHuntType { // Access wrapped value directly
            case .geolocation:
                print("Coordinator placeObjects: Handling Geolocation hunt.")
                guard !self.objectLocations.isEmpty else { // Access wrapped value directly
                    print("Coordinator placeObjects: Guard FAILED - objectLocations is empty for geolocation hunt.")
                    return
                }
                guard self.objectType != .none else { // Access wrapped value directly
                    print("Coordinator placeObjects: Guard FAILED - objectType is .none for geolocation hunt.")
                    return
                }

                print("Coordinator placeObjects: Placing \(self.objectLocations.count) objects of type \(self.objectType.rawValue)") // Access wrapped values directly

                for location in self.objectLocations { // Iterate over wrapped value directly
                    print("Coordinator placeObjects: Processing location \(location)")
                    let arPosition = convertToARWorldCoordinate(objectLocation: location, referenceLocation: refLoc)
                    let anchor = AnchorEntity(world: arPosition)
                    guard let entity = createEntity(for: self.objectType) else { continue } // Access wrapped value directly
                    anchor.addChild(entity)

                    if let baseAnchor = self.baseAnchor {
                        baseAnchor.addChild(anchor)
                        print("Coordinator placeObjects: Added anchor to self.baseAnchor")
                    } else {
                        arView.scene.addAnchor(anchor)
                        print("Coordinator placeObjects: WARNING - Added anchor directly to arView.scene (self.baseAnchor not found)")
                    }
                    newEntities.append(entity)
                    newAnchors.append(anchor)
                }

            case .proximity:
                print("Coordinator placeObjects: Handling Proximity hunt.")
                guard !self.proximityMarkers.isEmpty else { // Access wrapped value directly
                    print("Coordinator placeObjects: Guard FAILED - proximityMarkers is empty for proximity hunt.")
                    return
                }
                // For proximity, we'll default to placing Coin entities as discussed
                let objectTypeForProximity: ARObjectType = .coin
                guard objectTypeForProximity != .none else {
                     print("Coordinator placeObjects: Guard FAILED - objectType for proximity is .none.")
                     return
                }

                print("Coordinator placeObjects: Placing \(self.proximityMarkers.count) objects for proximity hunt (type: \(objectTypeForProximity.rawValue))") // Access wrapped value directly

                for marker in self.proximityMarkers { // Iterate over wrapped value directly
                    print("Coordinator placeObjects: Processing proximity marker: Dist=\(marker.dist), Dir=\(marker.dir)")

                    guard let headingRadians = self.heading?.trueHeading.degreesToRadians else {
                         print("Coordinator placeObjects: Skipping proximity marker placement - Heading not available.")
                         continue // Cannot place proximity markers without a valid heading
                    }

                    guard let markerAngleRadians = parseDirectionStringToRadians(dir: marker.dir) else {
                         print("Coordinator placeObjects: Skipping proximity marker placement - Failed to parse direction string: \(marker.dir)")
                         continue // Cannot place proximity markers without a valid direction
                    }

                    // Calculate the position relative to the base anchor (which is rotated to align Z with North)
                    // A marker at distance D and direction M degrees from North should be placed at:
                    // x = D * sin(M_radians)
                    // z = -D * cos(M_radians) // Negative Z because ARKit's Z is typically forward/south
                    // Y is typically 0 for objects on the ground plane.

                    let x = Float(marker.dist * sin(Double(markerAngleRadians)))
                    let z = Float(-marker.dist * cos(Double(markerAngleRadians))) // Negative Z for forward

                    let arPosition = SIMD3<Float>(x, 0, z) // Position relative to the base anchor (aligned to North)

                    let anchor = AnchorEntity(world: arPosition)
                    guard let entity = createEntity(for: objectTypeForProximity) else { continue }
                    anchor.addChild(entity)

                    if let baseAnchor = self.baseAnchor {
                        baseAnchor.addChild(anchor)
                        print("Coordinator placeObjects: Added proximity anchor to self.baseAnchor at position \(arPosition)")
                    } else {
                        arView.scene.addAnchor(anchor)
                        print("Coordinator placeObjects: WARNING - Added proximity anchor directly to arView.scene (self.baseAnchor not found) at position \(arPosition)")
                    }
                    newEntities.append(entity)
                    newAnchors.append(anchor)
                }

            case .none:
                print("Coordinator placeObjects: No hunt type specified.")
                self.statusMessage = "No hunt data loaded."
                return // Exit if no hunt type
            case .some(let actualHuntType): // Handle any other potential future hunt types
                print("Coordinator placeObjects: Unhandled hunt type: \(actualHuntType)") // Use the unwrapped value
                self.statusMessage = "Unsupported hunt type."
                return
            }

            // Status message and entity/anchor updates are done after the switch
            self.statusMessage = "Loot placed successfully!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusMessage = ""
            }

            self.coinEntities = newEntities // Rename this to placedEntities or similar? Keeping for now.
            self.anchors = newAnchors
            print("Coordinator updated with \(newAnchors.count) anchors/entities.")
        }

        // Helper to create model entity based on type
        private func createEntity(for type: ARObjectType) -> ModelEntity? {
            switch type {
            case .coin:
                return CoinEntityFactory.makeCoin()
            case .dollarSign:
                do {
                    let dollarSign = try ModelEntity.loadModel(named: "DollarSign")
                    dollarSign.scale = SIMD3<Float>(repeating: 0.02)
                    return dollarSign
                } catch {
                    print("Error loading DollarSign model: \(error). Falling back to coin.")
                    return CoinEntityFactory.makeCoin() // Fallback
                }
            case .none:
                return nil
            }
        }
        
        // Simplified conversion function
        private func convertToARWorldCoordinate(objectLocation: CLLocationCoordinate2D, referenceLocation: CLLocationCoordinate2D) -> SIMD3<Float> {
            let referenceCLLocation = CLLocation(latitude: referenceLocation.latitude, longitude: referenceLocation.longitude)
            let objectCLLocation = CLLocation(latitude: objectLocation.latitude, longitude: objectLocation.longitude)
            let lat1 = referenceCLLocation.coordinate.latitude
            let lon1 = referenceCLLocation.coordinate.longitude
            let lat2 = objectCLLocation.coordinate.latitude
            let lon2 = objectCLLocation.coordinate.longitude
            let deltaNorth = (lat2 - lat1) * metersPerDegree
            let deltaEast = (lon2 - lon1) * metersPerDegree * cos(Coordinator.degreesToRadians(lat1))
            return SIMD3<Float>(Float(deltaEast), 0, Float(-deltaNorth))
        }
        
        // Method to align the AR world to true north
        private func alignARWorldToNorth(arView: ARView, heading: CLLocationDirection) {
            print("Coordinator alignARWorldToNorth: Called with heading \(heading).")
            // Create or get the base anchor if it doesn't exist
            if baseAnchor == nil {
                baseAnchor = AnchorEntity(world: [0,0,0]) // Create anchor at world origin
                arView.scene.addAnchor(baseAnchor!) // Add it to the scene
                print("Coordinator alignARWorldToNorth: Created and added base anchor to scene.")
            }
            
            guard let baseAnchor = baseAnchor else {
                print("Coordinator alignARWorldToNorth: ERROR - baseAnchor is nil after attempting to create it.")
                return
            }

            // Calculate the rotation needed to align the AR world's positive Z-axis with true north (0 degrees)
            // A heading of X means the device is pointing X degrees east of north.
            // We need to rotate the AR world by -X degrees around the Y-axis to make north (0 degrees) align with the Z-axis.
            let rotationAngle = -Float(Coordinator.degreesToRadians(heading)) // Use Coordinator's method
            let rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0]) // Rotate around Y-axis

            // Apply the rotation to the base anchor
            baseAnchor.transform.rotation = rotation
            print("Base anchor rotated to align AR world to true north with rotation: \(rotationAngle) radians")
            
            // Update status message
            DispatchQueue.main.async {
                self.statusMessage = "Aligned to North" // Access wrapped value directly
                // Reset status message after 2 seconds
                 DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                     self.statusMessage = "" // Access wrapped value directly
                 }
            }
        }

        @objc func updateRotation(displayLink: CADisplayLink) {
            guard !coinEntities.isEmpty else { return } // Don't process if no entities

            let now = displayLink.timestamp
            let dt: Float
            if let last = lastTimestamp {
                dt = Float(now - last)
            } else {
                dt = 0 // First frame
            }
            lastTimestamp = now

            // Angle increment for this frame
            let anglePerSecond: Float = 2 * .pi / Float(revolutionDuration)
            accumulatedAngle += anglePerSecond * dt

            // Spin all entities
            let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])
            for entity in coinEntities {
                if self.objectType == .coin { // Access wrapped value directly
                    let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    entity.transform.rotation = yRot * xRot
                } else {
                    entity.transform.rotation = yRot
                }
            }

            // Proximity check
            guard let arView = arView,
                  let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

            // Iterate backwards safely for removal
            for index in anchors.indices.reversed() {
                 guard index < coinEntities.count else { continue } // Bounds check

                 let anchor = anchors[index]
                 let entity = coinEntities[index] // Get corresponding entity
                 let entityWorldPosition = entity.position(relativeTo: nil) // Use entity's world position

                 let distance = simd_distance(cameraPosition, entityWorldPosition)

                 if distance < 0.25 { // Increased distance slightly for easier collection
                    print("Object collected at distance: \(distance)")
                    playCoinSound()

                    // Remove anchor from the base anchor
                    anchor.removeFromParent()

                    // Remove from coordinator arrays
                    anchors.remove(at: index)
                    coinEntities.remove(at: index)

                    // Trigger callback
                    onCoinCollected?()
                 }
            }
        }

        func playCoinSound() {
            guard let url = Bundle.main.url(forResource: "coin", withExtension: "mp3") else {
                print("Missing coin.mp3 in app bundle")
                return
            }
            do {
                // Stop previous sound if playing
                audioPlayer?.stop()
                // Create and play new instance
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Failed to play coin sound: \(error)")
            }
        }
        
        // Method to clear anchors by removing children from the base anchor
        func clearAnchors() {
            guard let baseAnchor = baseAnchor else { return }
            baseAnchor.children.removeAll() // Remove all children from the base anchor
            anchors.removeAll()
            coinEntities.removeAll()
            print("Cleared all anchors from base anchor.")
        }

        // MARK: - ARSessionDelegate Methods
        // Implement if needed, e.g., for error handling or session updates
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session Failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                 self.statusMessage = "AR Session Failed: \(error.localizedDescription)" // Access wrapped value directly
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session Interrupted")
            DispatchQueue.main.async {
                 self.statusMessage = "AR Session Interrupted" // Access wrapped value directly
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session Interruption Ended")
            DispatchQueue.main.async {
                 self.statusMessage = "AR Session Resumed" // Access wrapped value directly
                 // Reset status message after 2 seconds
                 DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                     self.statusMessage = "" // Access wrapped value directly
                 }
            }
            // Consider reloading configuration or resetting tracking
        }
        
        // Implement didUpdate to capture heading updates
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // This delegate method is called frequently.
            // We only need the heading for initial alignment.
            // The heading is passed via the binding and observed in the Coordinator's didSet.
            // No need to process heading here if it's handled by the binding.
        }

        // Helper function to parse direction string (e.g., "N32E") into radians
        // Assuming format "Cardinal Degrees Cardinal" e.g., "N32E", "S45W", "E90S", "W0N" (pure West)
        // Angle is clockwise from North (positive Z in AR world after alignment)
        private func parseDirectionStringToRadians(dir: String) -> Float? {
            let pattern = #"^([NESW])(\d*)?([NESW])?$"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: dir, options: [], range: NSRange(location: 0, length: dir.utf16.count)) else {
                print("Failed to parse direction string format: \(dir)")
                return nil
            }

            var angleDegrees: Double = 0
            var baseAngle: Double = 0 // Angle for the first cardinal (N=0, E=90, S=180, W=270)
            var deflectionAngle: Double = 0 // Degrees after the first cardinal
            var deflectionDirection: Int = 1 // 1 for E/N (clockwise from base), -1 for W/S (counter-clockwise from base)

            // Extract components
            if match.numberOfRanges > 1, let range1 = Range(match.range(at: 1), in: dir) {
                let cardinal1 = String(dir[range1])
                switch cardinal1 {
                case "N": baseAngle = 0
                case "E": baseAngle = 90
                case "S": baseAngle = 180
                case "W": baseAngle = 270
                default: return nil // Should not happen with regex
                }
            } else { return nil }

            if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: dir), !range2.isEmpty {
                if let degrees = Double(dir[range2]) {
                    deflectionAngle = degrees
                } else {
                     // Handle cases like "N" or "E" without degrees
                     deflectionAngle = 0
                }
            } else {
                     // Handle cases like "N" or "E" without degrees
                     deflectionAngle = 0
            }

            if match.numberOfRanges > 3, let range3 = Range(match.range(at: 3), in: dir) {
                let cardinal2 = String(dir[range3])
                // Determine deflection direction based on cardinal1 and cardinal2
                // If cardinal1 is N or S, cardinal2 determines E (+deflection) or W (-deflection)
                // If cardinal1 is E or W, cardinal2 determines N (+deflection from E/W base) or S (-deflection from E/W base)
                switch (dir.prefix(1), cardinal2) {
                case ("N", "E"), ("E", "S"), ("S", "W"), ("W", "N"):
                    deflectionDirection = 1 // Clockwise deflection from base
                case ("N", "W"), ("E", "N"), ("S", "E"), ("W", "S"):
                    deflectionDirection = -1 // Counter-clockwise deflection from base
                default:
                     // Handle pure cardinal directions like "N", "E", "S", "W"
                     if dir.count == 1 {
                         deflectionAngle = 0 // No deflection for pure cardinal
                         deflectionDirection = 1 // Doesn't matter
                     } else {
                         print("Failed to parse direction string format: \(dir) - Invalid cardinal combination")
                         return nil
                     }
                }
            } else {
                 // Handle pure cardinal directions like "N", "E", "S", "W"
                 if dir.count == 1 {
                     deflectionAngle = 0 // No deflection for pure cardinal
                     deflectionDirection = 1 // Doesn't matter
                 } else {
                     print("Failed to parse direction string format: \(dir) - Missing second cardinal")
                     return nil
                 }
            }
            
            // Calculate final angle
            angleDegrees = baseAngle + (deflectionAngle * Double(deflectionDirection))
            
            // Normalize angle to be between 0 and 360
            angleDegrees = angleDegrees.truncatingRemainder(dividingBy: 360)
            if angleDegrees < 0 {
                angleDegrees += 360
            }

            print("Parsed direction string \(dir) to \(angleDegrees) degrees")
            return Float(angleDegrees * .pi / 180.0) // Convert to radians
        }
    } // End Coordinator Class
} // End Struct ARViewContainer
