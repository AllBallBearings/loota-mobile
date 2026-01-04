import RealityKit
import SwiftUI
import UIKit

struct CoinSimulatorView: View {
  @State private var flipX = false
  @State private var flipY = false
  @State private var flipZ = false

  var body: some View {
    VStack(spacing: 16) {
      CoinSimulatorRealityView(flipX: $flipX, flipY: $flipY, flipZ: $flipZ)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)

      HStack(spacing: 12) {
        Toggle("Flip X", isOn: $flipX)
        Toggle("Flip Y", isOn: $flipY)
        Toggle("Flip Z", isOn: $flipZ)
      }
      .toggleStyle(.button)
      .padding(.horizontal, 16)
    }
    .padding(.vertical, 24)
  }
}

struct CoinSimulatorRealityView: UIViewRepresentable {
  @Binding var flipX: Bool
  @Binding var flipY: Bool
  @Binding var flipZ: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> ARView {
    let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    arView.environment.background = .color(UIColor.black)

    let coin = CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
    coin.name = "coin_model"

    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(coin)

    let light = DirectionalLight()
    light.light.color = .white
    light.light.intensity = 2000
    light.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
    anchor.addChild(light)

    let cameraAnchor = AnchorEntity(world: .zero)
    let camera = PerspectiveCamera()
    camera.look(at: .zero, from: [0, 0.05, 0.5], relativeTo: nil)
    cameraAnchor.addChild(camera)

    arView.scene.addAnchor(anchor)
    arView.scene.addAnchor(cameraAnchor)

    context.coordinator.arView = arView
    context.coordinator.anchor = anchor
    context.coordinator.coin = coin
    context.coordinator.baseRotation = coin.transform.rotation
    context.coordinator.flipX = flipX
    context.coordinator.flipY = flipY
    context.coordinator.flipZ = flipZ
    context.coordinator.startSpinning()

    CoinEntityFactory.preloadCoinModel { [weak coordinator = context.coordinator] success in
      guard success else { return }
      DispatchQueue.main.async {
        coordinator?.replaceCoinIfNeeded()
      }
    }

    return arView
  }

  func updateUIView(_ uiView: ARView, context: Context) {
    context.coordinator.flipX = flipX
    context.coordinator.flipY = flipY
    context.coordinator.flipZ = flipZ
    context.coordinator.applyRotation(flipX: flipX, flipY: flipY, flipZ: flipZ)
  }

  final class Coordinator {
    weak var arView: ARView?
    var anchor: AnchorEntity?
    var coin: ModelEntity?
    var baseRotation = simd_quatf()
    var flipX = false
    var flipY = false
    var flipZ = false
    private var displayLink: CADisplayLink?
    private var spinAngle: Float = 0

    func startSpinning() {
      displayLink?.invalidate()
      let link = CADisplayLink(target: self, selector: #selector(step))
      link.add(to: .main, forMode: .common)
      displayLink = link
    }

    @objc private func step() {
      spinAngle += 0.02
      applyRotation(flipX: flipX, flipY: flipY, flipZ: flipZ)
    }

    func applyRotation(flipX: Bool, flipY: Bool, flipZ: Bool) {
      guard let coin else { return }
      let flipQuat =
        simd_quatf(angle: flipX ? .pi : 0, axis: [1, 0, 0])
        * simd_quatf(angle: flipY ? .pi : 0, axis: [0, 1, 0])
        * simd_quatf(angle: flipZ ? .pi : 0, axis: [0, 0, 1])
      let spin = simd_quatf(angle: spinAngle, axis: [0, 0, 1])
      coin.transform.rotation = baseRotation * flipQuat * spin
    }

    func replaceCoinIfNeeded() {
      guard let anchor else { return }
      guard CoinEntityFactory.isCoinModelReady else { return }

      let newCoin = CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
      newCoin.name = "coin_model"

      coin?.removeFromParent()
      anchor.addChild(newCoin)

      coin = newCoin
      baseRotation = newCoin.transform.rotation
      applyRotation(flipX: flipX, flipY: flipY, flipZ: flipZ)
    }

    deinit {
      displayLink?.invalidate()
    }
  }
}
