// GiftCardTestView.swift
// Debug view for testing gift card orientation with real-time axis visualization and rotation controls

import SwiftUI
import RealityKit
import ARKit

struct GiftCardTestView: View {
    @State private var rotationX: Float = 0
    @State private var rotationY: Float = 0
    @State private var rotationZ: Float = 0
    @State private var showAxes = true
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        ZStack {
            // AR View
            GiftCardTestARView(
                rotationX: $rotationX,
                rotationY: $rotationY,
                rotationZ: $rotationZ,
                showAxes: $showAxes
            )
            .edgesIgnoringSafeArea(.all)

            // Control Panel
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Text("Gift Card Orientation Test")
                        .font(.headline)
                        .foregroundColor(.white)

                    // Axis toggle
                    Toggle("Show Axes", isOn: $showAxes)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    // X-axis rotation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("X-axis (Red): \(Int(rotationX))°")
                            .foregroundColor(.red)
                            .font(.caption)
                        Slider(value: $rotationX, in: -180...180, step: 15)
                            .accentColor(.red)
                    }
                    .padding(.horizontal)

                    // Y-axis rotation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Y-axis (Green): \(Int(rotationY))°")
                            .foregroundColor(.green)
                            .font(.caption)
                        Slider(value: $rotationY, in: -180...180, step: 15)
                            .accentColor(.green)
                    }
                    .padding(.horizontal)

                    // Z-axis rotation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Z-axis (Blue): \(Int(rotationZ))°")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Slider(value: $rotationZ, in: -180...180, step: 15)
                            .accentColor(.blue)
                    }
                    .padding(.horizontal)

                    // Quick presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            PresetButton(title: "Reset", x: 0, y: 0, z: 0, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "X+90", x: 90, y: 0, z: 0, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "X-90", x: -90, y: 0, z: 0, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "Y+90", x: 0, y: 90, z: 0, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "Y-90", x: 0, y: -90, z: 0, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "Z+90", x: 0, y: 0, z: 90, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                            PresetButton(title: "Z-90", x: 0, y: 0, z: -90, rotationX: $rotationX, rotationY: $rotationY, rotationZ: $rotationZ)
                        }
                        .padding(.horizontal)
                    }

                    // Current rotation display
                    Text("Rotation: X:\(Int(rotationX))° Y:\(Int(rotationY))° Z:\(Int(rotationZ))°")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)

                    // Close button
                    Button("Close Test View") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
                .padding()
            }
        }
    }
}

struct PresetButton: View {
    let title: String
    let x: Float
    let y: Float
    let z: Float
    @Binding var rotationX: Float
    @Binding var rotationY: Float
    @Binding var rotationZ: Float

    var body: some View {
        Button(title) {
            rotationX = x
            rotationY = y
            rotationZ = z
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.6))
        .foregroundColor(.white)
        .cornerRadius(8)
        .font(.caption)
    }
}

struct GiftCardTestARView: UIViewRepresentable {
    @Binding var rotationX: Float
    @Binding var rotationY: Float
    @Binding var rotationZ: Float
    @Binding var showAxes: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        // Create anchor
        let anchor = AnchorEntity(plane: .horizontal)
        arView.scene.addAnchor(anchor)

        // Store anchor in coordinator
        context.coordinator.anchor = anchor
        context.coordinator.arView = arView

        // Load gift card model
        context.coordinator.loadGiftCard()

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.updateRotation(x: rotationX, y: rotationY, z: rotationZ)
        context.coordinator.updateAxesVisibility(show: showAxes)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var anchor: AnchorEntity?
        var arView: ARView?
        var giftCardEntity: ModelEntity?
        var axesEntity: Entity?

        func loadGiftCard() {
            guard let anchor = anchor else { return }

            // Preload and create gift card
            GiftCardEntityFactory.preloadGiftCardModel { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self, let anchor = self.anchor else { return }

                    if success {
                        let giftCard = GiftCardEntityFactory.makeGiftCard()
                        // Remove any default rotation from the factory
                        giftCard.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                        giftCard.position = [0, 0.2, -0.5]  // Position in front of camera

                        anchor.addChild(giftCard)
                        self.giftCardEntity = giftCard

                        // Create axes
                        self.createAxes(parent: anchor)
                    } else {
                        print("Failed to load gift card model")
                    }
                }
            }
        }

        func createAxes(parent: AnchorEntity) {
            let axesContainer = Entity()
            axesContainer.position = [0, 0.2, -0.5]  // Same position as gift card

            let axisLength: Float = 0.3
            let axisThickness: Float = 0.005

            // X-axis (Red)
            let xAxis = ModelEntity(
                mesh: .generateBox(width: axisLength, height: axisThickness, depth: axisThickness),
                materials: [SimpleMaterial(color: .red, isMetallic: false)]
            )
            xAxis.position = [axisLength / 2, 0, 0]
            axesContainer.addChild(xAxis)

            // Y-axis (Green)
            let yAxis = ModelEntity(
                mesh: .generateBox(width: axisThickness, height: axisLength, depth: axisThickness),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            )
            yAxis.position = [0, axisLength / 2, 0]
            axesContainer.addChild(yAxis)

            // Z-axis (Blue)
            let zAxis = ModelEntity(
                mesh: .generateBox(width: axisThickness, height: axisThickness, depth: axisLength),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            zAxis.position = [0, 0, axisLength / 2]
            axesContainer.addChild(zAxis)

            parent.addChild(axesContainer)
            self.axesEntity = axesContainer
        }

        func updateRotation(x: Float, y: Float, z: Float) {
            guard let giftCard = giftCardEntity else { return }

            let radX = x * .pi / 180
            let radY = y * .pi / 180
            let radZ = z * .pi / 180

            let rotX = simd_quatf(angle: radX, axis: [1, 0, 0])
            let rotY = simd_quatf(angle: radY, axis: [0, 1, 0])
            let rotZ = simd_quatf(angle: radZ, axis: [0, 0, 1])

            // Apply rotations in order: Z, then Y, then X
            giftCard.transform.rotation = rotX * rotY * rotZ
        }

        func updateAxesVisibility(show: Bool) {
            axesEntity?.isEnabled = show
        }
    }
}
