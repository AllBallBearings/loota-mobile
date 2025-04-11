// ContentView.swift
// AR Cube Example

import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for world tracking
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [])
        
        // Create an anchor 1.524m in front, 0.609m up (5ft, 2ft)
        let anchor = AnchorEntity(world: [0, 0.609, -1.524])
        
        // Create a flat disc (coin) using a cylinder mesh
        let coinRadius: Float = 0.12
        let coinHeight: Float = 0.02
        let coinMesh = MeshResource.generateCylinder(height: coinHeight, radius: coinRadius)
        let coinMaterial = SimpleMaterial(color: .yellow, isMetallic: true)
        let coinEntity = ModelEntity(mesh: coinMesh, materials: [coinMaterial])

        // Rotate the coin so it stands on its edge (vertical, like a coin on a table)
        coinEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

        // Add coin to anchor
        anchor.addChild(coinEntity)
        arView.scene.addAnchor(anchor)

        // Animate the coin spinning about its y-axis (vertical axis in world space)
        // Use CADisplayLink for smooth, continuous rotation
        let revolutionDuration: TimeInterval = 1.5 // 1 revolution per 1.5 seconds
        let displayLink = CADisplayLink(target: context.coordinator, selector: #selector(context.coordinator.updateRotation))
        displayLink.add(to: .main, forMode: .default)

        // Store references in the coordinator for animation
        context.coordinator.coinEntity = coinEntity
        context.coordinator.anchor = anchor
        context.coordinator.revolutionDuration = revolutionDuration
        context.coordinator.accumulatedAngle = 0

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var coinEntity: ModelEntity?
        var anchor: AnchorEntity?
        var revolutionDuration: TimeInterval = 1.5
        var accumulatedAngle: Float = 0
        var lastTimestamp: CFTimeInterval?

        @objc func updateRotation(displayLink: CADisplayLink) {
            guard let coinEntity = coinEntity else { return }
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

            // Keep the coin standing on its edge (x: 90deg), and rotate about y
            let xRot = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let yRot = simd_quatf(angle: accumulatedAngle, axis: [0, 1, 0])
            coinEntity.transform.rotation = yRot * xRot
        }
    }
}
