// ARViewContainer.swift

import SwiftUI
import RealityKit
import CoreLocation
import ARKit
import AVFoundation

struct ARViewContainer: UIViewRepresentable {
    @Binding var objectLocation: CLLocationCoordinate2D?
    @Binding var referenceLocation: CLLocationCoordinate2D?
    var onCoinCollected: (() -> Void)?
    var objectType: ARObjectType

    public init(objectLocation: Binding<CLLocationCoordinate2D?>,
               referenceLocation: Binding<CLLocationCoordinate2D?>,
               onCoinCollected: (() -> Void)? = nil,
               objectType: ARObjectType) {
        self._objectLocation = objectLocation
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

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for world tracking
        let worldConfig = ARWorldTrackingConfiguration()
        worldConfig.environmentTexturing = .automatic
        worldConfig.planeDetection = [.horizontal, .vertical]
        let config = worldConfig
        
        arView.session.run(config, options: [])
        arView.session.delegate = context.coordinator

        // Setup display link for animations (can be done early)
        let revolutionDuration: TimeInterval = 1.5 // 1 revolution per 1.5 seconds
        let displayLink = CADisplayLink(target: context.coordinator, selector: #selector(context.coordinator.updateRotation))
        displayLink.add(to: .main, forMode: .default)

        // Delay object placement slightly to allow AR session to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only add objects if objectType is not .none
            var entities: [ModelEntity] = []
            var anchors: [AnchorEntity] = []

            if self.objectType != .none { // Need self here due to closure
                guard let objectLocation = self.objectLocation,
                      let referenceLocation = self.referenceLocation else {
                print("Missing location data")
                return
            }
            
            let arPosition = convertToARWorldCoordinate(
                objectLocation: objectLocation,
                referenceLocation: referenceLocation
            )
            
            let positions: [SIMD3<Float>] = [arPosition]

            // Use all positions for coins, but only the center one for dollar signs
            let positionsToUse = (objectType == .dollarSign) ? [positions[1]] : positions

            for pos in positionsToUse {
                let anchor = AnchorEntity(world: pos)
                let entity: ModelEntity
                switch objectType {
                case .coin:
                    entity = CoinEntityFactory.makeCoin()
                case .dollarSign:
                    // Try to load DollarSign.usdz from the bundle
                    if let dollarSign = try? ModelEntity.loadModel(named: "DollarSign") {
                        entity = dollarSign
                        // Further reduced scale
                        entity.scale = SIMD3<Float>(repeating: 0.02) 
                    } else {
                        // fallback to coin if model not found
                        entity = CoinEntityFactory.makeCoin()
                    }
                default:
                    entity = CoinEntityFactory.makeCoin()
                }
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)
                entities.append(entity)
                    anchors.append(anchor)
                }
            }

            // Store references in the coordinator for animation and proximity logic
            // Must be done *inside* the asyncAfter block as entities/anchors are created here
            context.coordinator.coinEntities = entities
            context.coordinator.anchors = anchors
            context.coordinator.arView = arView // Weak reference ok here
            context.coordinator.onCoinCollected = self.onCoinCollected // Need self
        }

        // Setup coordinator properties not dependent on delayed creation
        context.coordinator.revolutionDuration = revolutionDuration
        context.coordinator.accumulatedAngle = 0
        // Note: arView and onCoinCollected are assigned inside the delay block now

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Empty but required
    }
    
    func makeCoordinator() -> Coordinator {
        // Pass the objectType when creating the Coordinator
        Coordinator(objectType: objectType)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var objectType: ARObjectType // Store object type
        var onCoinCollected: (() -> Void)?
        var coinEntities: [ModelEntity] = []

        // Initializer to receive objectType
        init(objectType: ARObjectType) {
            self.objectType = objectType
        }
        var anchors: [AnchorEntity] = []
        var revolutionDuration: TimeInterval = 1.5
        var accumulatedAngle: Float = 0
        var lastTimestamp: CFTimeInterval?
        weak var arView: ARView?

        @objc func updateRotation(displayLink: CADisplayLink) {
            let now = displayLink.timestamp
            let dt: Float
            if let last = lastTimestamp {
                dt = Float(now - last)
            } else {
                dt = 0
            }
            lastTimestamp = now

            // Angle increment for this frame
            let anglePerSecond: Float = 2 * .pi / Float(revolutionDuration)
            accumulatedAngle += anglePerSecond * dt

            // Spin all entities
            let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])
            for entity in coinEntities { // Renamed 'coin' to 'entity' for clarity
                if self.objectType == .coin {
                    // Apply initial X rotation only for coins
                    let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    entity.transform.rotation = yRot * xRot
                } else {
                    // Apply only Y rotation for other types (dollar sign)
                    entity.transform.rotation = yRot
                }
            }

            // Proximity check: play sound and remove entity if user is within 0.1524m (6 inches)
            guard let arView = arView,
                  let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            for (index, anchor) in anchors.enumerated().reversed() {
                let coinPosition = anchor.position(relativeTo: nil)
                let distance = simd_distance(cameraPosition, coinPosition)
                if distance < 0.1524, index < coinEntities.count {
                    // Play sound
                    playCoinSound()
                    // Remove coin and anchor
                    arView.scene.removeAnchor(anchor)
                    anchors.remove(at: index)
                    coinEntities.remove(at: index)
                    // Increment counter
                    onCoinCollected?()
                }
            }
        }

        var audioPlayer: AVAudioPlayer?

        func playCoinSound() {
            // Play a xylophone note sound (requires "xylophone_c.wav" in app bundle)
            guard let url = Bundle.main.url(forResource: "coin", withExtension: "mp3") else {
                print("Missing coin.mp3 in app bundle")
                return
            }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Failed to play coin sound: \(error)")
            }
        }
    }
}
