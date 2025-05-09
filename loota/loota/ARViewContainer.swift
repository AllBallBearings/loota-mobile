// ARViewContainer.swift

import SwiftUI
import RealityKit
import CoreLocation
import ARKit
import AVFoundation
import Combine // Import Combine for sink

struct ARViewContainer: UIViewRepresentable {
    @Binding var objectLocations: [CLLocationCoordinate2D] // Changed to array
    @Binding var referenceLocation: CLLocationCoordinate2D?
    @Binding var statusMessage: String // Add status message binding
    @Binding var heading: CLHeading? // Add heading binding
    var onCoinCollected: (() -> Void)?
    @Binding var objectType: ARObjectType // Changed to @Binding

    // Correct initializer signature
    public init(objectLocations: Binding<[CLLocationCoordinate2D]>,
               referenceLocation: Binding<CLLocationCoordinate2D?>,
               statusMessage: Binding<String>, // Add status message binding
               heading: Binding<CLHeading?>, // Add heading binding
               onCoinCollected: (() -> Void)? = nil,
               objectType: Binding<ARObjectType>) { // Changed to Binding<ARObjectType>
        print("ARViewContainer init: objectType=\(objectType.wrappedValue.rawValue), objectLocations.count=\(objectLocations.wrappedValue.count), refLocation=\(String(describing: referenceLocation.wrappedValue)), heading=\(String(describing: heading.wrappedValue?.trueHeading))")
        self._objectLocations = objectLocations
        self._referenceLocation = referenceLocation
        self._statusMessage = statusMessage
        self._heading = heading // Assign heading binding
        self.onCoinCollected = onCoinCollected
        self._objectType = objectType // Changed to assign to _objectType
    }

    // GPS conversion constants are now in Coordinator

    // MARK: - UIViewRepresentable Methods

    func makeUIView(context: Context) -> ARView {
        print("ARViewContainer makeUIView called.")
        // Reset alignment flag for debugging, to ensure alignment is attempted each time view is made
        // context.coordinator.hasAlignedToNorth = false // Potentially problematic if coordinator is reused; better to do this in init if needed
        // For now, let's rely on the Coordinator's own initialization of hasAlignedToNorth = false

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
        // updateObjectPlacement(arView: arView, context: context) // Removed initial call here

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
    }

    func makeCoordinator() -> Coordinator {
        // Initialize coordinator with the initial wrapped value of referenceLocation
        let coordinator = Coordinator(
            initialReferenceLocation: self.referenceLocation, // Pass wrapped value
            objectLocations: $objectLocations,
            objectType: $objectType,
            statusMessage: $statusMessage
        )
        // Set the placeObjectsAction on the newly created coordinator instance
        // The coordinator's placeObjectsAction will call its own placeObjectsInARView method.
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
             statusMessage: Binding<String>) {
            print("Coordinator init: Setting up.")
            self.referenceLocation = initialReferenceLocation // Assign initial value
            self._objectLocations = objectLocations
            self._objectType = objectType
            self._statusMessage = statusMessage
            super.init()
            print("Coordinator init: Initial referenceLocation = \(String(describing: self.referenceLocation))")
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
            // Use self.referenceLocation (which is now a simple var)
            guard let refLoc = self.referenceLocation else {
                print("Coordinator placeObjects: Guard FAILED - self.referenceLocation is nil.")
                return
            }
            // Use self.objectLocations (the binding's wrappedValue)
            guard !self.objectLocations.isEmpty else {
                print("Coordinator placeObjects: Guard FAILED - objectLocations is empty.")
                return
            }
            // Use self.objectType (the binding's wrappedValue)
            guard self.objectType != .none else {
                print("Coordinator placeObjects: Guard FAILED - objectType is .none.")
                return
            }
            
            print("Coordinator placeObjects: Called with objectType=\(self.objectType.rawValue), objectLocations.count=\(self.objectLocations.count), refLoc=\(refLoc)")
            
            self.clearAnchors()

            var newEntities: [ModelEntity] = []
            var newAnchors: [AnchorEntity] = []

            print("Coordinator placeObjects: Placing \(self.objectLocations.count) objects of type \(self.objectType.rawValue)")

            for location in self.objectLocations {
                print("Coordinator placeObjects: Processing location \(location)")
                let arPosition = convertToARWorldCoordinate(objectLocation: location, referenceLocation: refLoc)
                let anchor = AnchorEntity(world: arPosition)
                guard let entity = createEntity(for: self.objectType) else { continue }
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

            self.statusMessage = "Loot placed successfully!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusMessage = ""
            }
            
            self.coinEntities = newEntities
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
    } // End Coordinator Class
} // End Struct ARViewContainer
