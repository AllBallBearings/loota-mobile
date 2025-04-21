// ARViewContainer.swift

import SwiftUI
import RealityKit
import ARKit
import AVFoundation
// Removed CoreLocation import

struct ARViewContainer: UIViewRepresentable {
    // Removed pinLocations binding
    @Binding var arViewRef: ARView? // Expose ARView to ContentView
    var onCoinCollected: (() -> Void)?
    var onDistanceUpdate: (([UUID: Float]) -> Void)? // Callback for distance updates
    var objectType: ARObjectType

    // Removed LocationManager and related state

    func makeUIView(context: Context) -> ARView {
        print("ARView makeUIView called.")
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView // Assign early
        arViewRef = arView // Expose to ContentView

        // --- AR Session Configuration ---
        print("Using ARWorldTrackingConfiguration.")
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [] // Plane detection not needed for simple placement
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        // --- Display Link for Animations ---
        context.coordinator.setupDisplayLink()

        // --- Initial Object Placement ---
        // Placement now happens in updateUIView when objectType changes.

        // --- Assign Coordinator Properties ---
        context.coordinator.objectType = self.objectType // Pass object type
        context.coordinator.onCoinCollected = self.onCoinCollected
        context.coordinator.onDistanceUpdate = self.onDistanceUpdate // Pass callback
        // Removed locationManager assignment

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("ARView updateUIView called. Object: \(objectType)")
        // This is called when @Bindings change (objectType)

        // If the object type changed, clear old anchors and place the new one.
        if context.coordinator.objectType != self.objectType {
            print("Object type changed to \(self.objectType). Clearing existing anchors.")
            clearAllAnchors(arView: uiView, context: context)
            context.coordinator.objectType = self.objectType // Update coordinator

            // Place the new object if one is selected (not .none)
            if self.objectType != .none {
                print("Placing new object: \(self.objectType)")
                placeSelectedObject(arView: uiView, context: context, objectType: self.objectType)
            }
        }
        // No other updates needed here for now. Rotation is handled by Coordinator's display link.
    }

    // Helper function to remove all placed anchors (Keep this)
    private func clearAllAnchors(arView: ARView, context: Context) {
        context.coordinator.anchors.forEach { arView.scene.removeAnchor($0) }
        context.coordinator.anchors.removeAll()
        context.coordinator.coinEntities.removeAll() // Clear entities as well
        print("Cleared all anchors (\(context.coordinator.anchors.count))")
        // Also clear distances in ContentView
        onDistanceUpdate?([:])
    }

    // New helper function to place the selected object in front of the camera
    private func placeSelectedObject(arView: ARView, context: Context, objectType: ARObjectType) {
        guard objectType != .none, let cameraTransform = arView.session.currentFrame?.camera.transform else {
            print("Cannot place object: No object selected or camera transform unavailable.")
            return
        }

        // Create the entity for the selected type
        guard let entity = createEntity(for: objectType) else {
            print("Failed to create entity for \(objectType).")
            return
        }

        // Calculate position 1 meter in front of the camera
        let positionInFront = SIMD3<Float>(0, 0, -1.0) // Z-axis is forward in camera space
        let worldPosition = cameraTransform * float4x4(translation: positionInFront)

        // Create an anchor at the calculated world position
        let anchor = AnchorEntity(world: worldPosition.translation)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        // Update coordinator's lists
        context.coordinator.coinEntities = [entity] // Only one entity now
        context.coordinator.anchors = [anchor]     // Only one anchor now
        print("Placed \(objectType) anchor at \(worldPosition.translation)")
    }


    // Helper to create the correct ModelEntity (Keep this)
    private func createEntity(for type: ARObjectType) -> ModelEntity? {
        switch type {
        case .coin:
            return CoinEntityFactory.makeCoin()
        case .dollarSign:
            // Restore original Dollar Sign loading logic
            do {
                print("Attempting to load DollarSign model...") // Log before try
                let dollarSign = try ModelEntity.loadModel(named: "DollarSign")
                print("...ModelEntity.loadModel succeeded.") // Log immediately after try
                // Use the increased scale for visibility
                dollarSign.scale = SIMD3<Float>(repeating: 0.2) // Increased scale (20cm)
                print("Scaled DollarSign entity.") // Changed log slightly
                return dollarSign
            } catch {
                // Print the specific error if loading fails
                print("❌ Failed to load DollarSign.usdz: \(error)")
                return nil // Return nil if model fails
            }
        case .none:
            return nil
        }
    }

    // Removed Coordinate Transformation Helpers

    // --- Coordinator ---
    func makeCoordinator() -> Coordinator {
        Coordinator() // No need to pass objectType initially, set in updateUIView
    }

    // Removed CLLocationManagerDelegate conformance
    class Coordinator: NSObject {
        var objectType: ARObjectType = .none // Default
        var onCoinCollected: (() -> Void)?
        var onDistanceUpdate: (([UUID: Float]) -> Void)? // Store callback
        var coinEntities: [ModelEntity] = [] // Will hold max 1 entity now
        var anchors: [AnchorEntity] = []     // Will hold max 1 anchor now
        var revolutionDuration: TimeInterval = 1.5
        var accumulatedAngle: Float = 0
        var lastTimestamp: CFTimeInterval?
        weak var arView: ARView?
        var displayLink: CADisplayLink?

        // Removed location-related properties (isUsingGeoTracking, locationManager, initialTransform, initialLocation)

        // Called from makeUIView
        func setupDisplayLink() {
            displayLink = CADisplayLink(target: self, selector: #selector(updateRotation))
            displayLink?.add(to: .main, forMode: .default)
            print("DisplayLink setup.")
        }

        // Removed setupLocationUpdates function

        @objc func updateRotation(displayLink: CADisplayLink) {
            // --- Rotation Animation --- (Logic remains the same, but applies to potentially fewer entities)
            guard let arView = arView else { return } // Ensure arView is available
            let now = displayLink.timestamp
            let dt: Float
            if let last = lastTimestamp {
                dt = Float(now - last)
            } else {
                dt = 0
            }
            lastTimestamp = now

            let anglePerSecond: Float = 2 * .pi / Float(revolutionDuration)
            accumulatedAngle += anglePerSecond * dt
            let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])

            for entity in coinEntities {
                if self.objectType == .coin {
                    let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    entity.transform.rotation = yRot * xRot
                } else {
                    entity.transform.rotation = yRot
                }
            }

            // --- Proximity Check --- (Keep as is, but ensure anchors/entities are valid)
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            let cameraPosition = cameraTransform.translation // Simplified access
            let proximityThreshold: Float = 0.3 // Increased threshold slightly (approx 1 foot)

            // Iterate safely (now likely only 0 or 1 anchor)
            var collected = false
            var currentDistances: [UUID: Float] = [:] // Temp dictionary for this frame

            if let anchor = anchors.first, let entity = coinEntities.first { // Check if anchor/entity exist
                 let objectPosition = anchor.position(relativeTo: nil) // World position
                 let distance = simd_distance(cameraPosition, objectPosition)
                 currentDistances[anchor.id] = distance // Store distance keyed by anchor ID

                 if distance < proximityThreshold {
                     print(">>> Object collected, distance: \(distance)") // Highlight collection
                     collected = true
                     playCoinSound()
                     onCoinCollected?() // Increment counter
                 }
            }

            // Remove collected item
            if collected {
                if let anchorToRemove = anchors.first {
                    arView.scene.removeAnchor(anchorToRemove)
                }
                anchors.removeAll()
                coinEntities.removeAll()
                print("Removed collected anchor and entity.")
                // Clear distances in ContentView as well
                currentDistances = [:] // Clear distances since object is gone
            }

            // Call the distance update callback
            // Send empty dictionary if object was just collected, otherwise send current distances
            onDistanceUpdate?(currentDistances)
        }

        // --- Sound Playing --- (Keep as is)
        var audioPlayer: AVAudioPlayer?
        func playCoinSound() {
            guard let url = Bundle.main.url(forResource: "coin", withExtension: "mp3") else {
                print("Missing coin.mp3 in app bundle")
                return
            }
            do {
                // Stop previous sound if playing
                if audioPlayer?.isPlaying == true {
                    audioPlayer?.stop()
                }
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Failed to play coin sound: \(error)")
            }
        }

        deinit {
            // Clean up display link
            displayLink?.invalidate()
            print("Coordinator deinit.")
        }
    } // End Coordinator Class
} // End Struct

// Removed degreesToRadians extension as it's no longer needed

// Helper extension for SIMD access (Keep this)
extension float4x4 {
    var translation: SIMD3<Float> {
        return columns.3.xyz
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        return SIMD3<Scalar>(x, y, z)
    }
}
