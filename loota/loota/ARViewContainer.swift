// ARViewContainer.swift

import SwiftUI
import RealityKit
import CoreLocation
import ARKit
import AVFoundation

struct ARViewContainer: UIViewRepresentable {
    @Binding var objectLocations: [CLLocationCoordinate2D] // Changed to array
    @Binding var referenceLocation: CLLocationCoordinate2D?
    var onCoinCollected: (() -> Void)?
    var objectType: ARObjectType

    // Correct initializer signature
    public init(objectLocations: Binding<[CLLocationCoordinate2D]>,
               referenceLocation: Binding<CLLocationCoordinate2D?>,
               onCoinCollected: (() -> Void)? = nil,
               objectType: ARObjectType) {
        self._objectLocations = objectLocations
        self._referenceLocation = referenceLocation
        self.onCoinCollected = onCoinCollected
        self.objectType = objectType
    }

    // GPS conversion constants
    private let metersPerDegree: Double = 111320.0 // Approximate meters per degree at equator

    private func convertToARWorldCoordinate(objectLocation: CLLocationCoordinate2D,
                                          referenceLocation: CLLocationCoordinate2D) -> SIMD3<Float> {
        let latDelta = objectLocation.latitude - referenceLocation.latitude
        let lonDelta = objectLocation.longitude - referenceLocation.longitude

        // Convert latitude/longitude differences to meters
        let x = Float(lonDelta * metersPerDegree)
        let z = Float(-latDelta * metersPerDegree) // Negative for ARKit's coordinate system

        return SIMD3<Float>(x, 0, z)
    }

    // MARK: - UIViewRepresentable Methods

    func makeUIView(context: Context) -> ARView {
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
        // Ensure coordinator is correctly referenced
        let displayLink = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.updateRotation))
        displayLink.add(to: .main, forMode: .default) // Use RunLoop.main and RunLoop.Mode.default

        // Assign callbacks and initial properties to coordinator
        context.coordinator.onCoinCollected = self.onCoinCollected
        context.coordinator.revolutionDuration = 1.5 // Example duration
        context.coordinator.objectType = self.objectType // Pass object type

        // Initial placement of objects (can also be done in updateUIView)
        updateObjectPlacement(arView: arView, context: context)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Called when bindings change. We might want to update object placement here
        // if objectLocations or referenceLocation changes significantly after initial setup.
        // For now, we'll handle initial placement in makeUIView's async block.
        // If objectLocations can change dynamically, add logic here to update anchors.
        
        // Update coordinator properties if they depend on bindings that might change
        context.coordinator.objectType = self.objectType
        context.coordinator.onCoinCollected = self.onCoinCollected
        
        // Consider triggering an update of object placements if needed
        // updateObjectPlacement(arView: uiView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator() // Initialize coordinator
    }
    
    // Helper function to place/update objects
    private func updateObjectPlacement(arView: ARView, context: Context) {
         // Delay object placement slightly to allow AR session to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Clear existing anchors managed by this view before adding new ones
            // (Important if locations can change dynamically)
            // context.coordinator.clearAnchors() // Add clearAnchors method to Coordinator if needed

            var newEntities: [ModelEntity] = []
            var newAnchors: [AnchorEntity] = []

            guard let referenceLocation = self.referenceLocation else {
                 print("Missing reference location data for placement")
                 // Assign empty arrays to coordinator if reference is missing
                 context.coordinator.coinEntities = []
                 context.coordinator.anchors = []
                 return
            }

            if self.objectType != .none && !self.objectLocations.isEmpty {
                print("Placing \(self.objectLocations.count) objects of type \(self.objectType.rawValue)")

                for location in self.objectLocations {
                    let arPosition = convertToARWorldCoordinate(
                        objectLocation: location,
                        referenceLocation: referenceLocation
                    )

                    let anchor = AnchorEntity(world: arPosition)
                    guard let entity = createEntity(for: self.objectType) else { continue } // Use helper

                    anchor.addChild(entity)
                    arView.scene.addAnchor(anchor) // Add anchor to the scene
                    newEntities.append(entity)
                    newAnchors.append(anchor)
                }
            } else {
                 print("No objects to place (type is .none or locations array is empty)")
            }

            // Update coordinator with the newly created anchors and entities
            context.coordinator.coinEntities = newEntities
            context.coordinator.anchors = newAnchors
            print("Coordinator updated with \(newAnchors.count) anchors/entities.")
        }
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
            return nil // Should not happen due to checks, but good practice
        }
    }


    // MARK: - Coordinator Class
    
    class Coordinator: NSObject, ARSessionDelegate {
        var objectType: ARObjectType = .none // Initialize with default
        var onCoinCollected: (() -> Void)?
        var coinEntities: [ModelEntity] = []
        var anchors: [AnchorEntity] = []
        var revolutionDuration: TimeInterval = 1.5
        var accumulatedAngle: Float = 0
        var lastTimestamp: CFTimeInterval?
        weak var arView: ARView?
        var audioPlayer: AVAudioPlayer? // Moved audio player here

        // Initializer (can be empty if properties are set later)
        override init() {
            super.init()
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
                if self.objectType == .coin {
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

                    // Remove anchor from scene *first*
                    arView.scene.removeAnchor(anchor)

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
        
        // Optional: Method to clear anchors if locations update dynamically
        func clearAnchors() {
            guard let arView = arView else { return }
            for anchor in anchors {
                arView.scene.removeAnchor(anchor)
            }
            anchors.removeAll()
            coinEntities.removeAll()
        }

        // MARK: - ARSessionDelegate Methods (Optional)
        // Implement if needed, e.g., for error handling or session updates
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session Failed: \(error.localizedDescription)")
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session Interrupted")
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session Interruption Ended")
            // Consider reloading configuration or resetting tracking
        }
    } // End Coordinator Class
} // End Struct ARViewContainer - THIS BRACE WAS LIKELY THE MISSING ONE
