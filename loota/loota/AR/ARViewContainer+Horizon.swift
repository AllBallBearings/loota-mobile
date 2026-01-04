import ARKit
import Foundation
import RealityKit
import UIKit

extension ARViewContainer.Coordinator {
  // Helper to create horizon line entity as a continuous 360-degree torus
  private func createHorizonLineEntity() -> ModelEntity {
    let majorRadius: Float = 30.0
    let minorRadius: Float = 0.05
    let horizonRingEntity = createTorusEntity(majorRadius: majorRadius, minorRadius: minorRadius)

    print("🌅 HORIZON_CREATE: Created continuous 360° torus - Major radius: \(majorRadius)m, Minor radius: \(minorRadius)m")
    print("🌅 HORIZON_CREATE: Color: Light blue with 50% opacity")

    return horizonRingEntity
  }

  // Helper to create a true continuous torus using custom mesh generation
  private func createTorusEntity(majorRadius: Float, minorRadius: Float) -> ModelEntity {
    let torusMesh = generateTorusMesh(majorRadius: majorRadius, minorRadius: minorRadius)

    let horizonColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.5)
    let material = UnlitMaterial(color: horizonColor)

    let horizonRingEntity = ModelEntity(mesh: torusMesh, materials: [material])
    horizonRingEntity.name = "horizon_torus_continuous"

    print("🌅 HORIZON_CREATE: Generated continuous torus mesh with \(majorRadius)m major radius, \(minorRadius)m minor radius")

    return horizonRingEntity
  }

  // Generate a continuous torus mesh using parametric equations
  func generateTorusMesh(majorRadius: Float, minorRadius: Float) -> MeshResource {
    let majorSegments = 64
    let minorSegments = 16

    var vertices: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    // Generate vertices and normals using torus parametric equations
    for i in 0..<majorSegments {
      let u = Float(i) * 2.0 * .pi / Float(majorSegments)

      for j in 0..<minorSegments {
        let v = Float(j) * 2.0 * .pi / Float(minorSegments)

        let cosV = cos(v)
        let sinV = sin(v)
        let cosU = cos(u)
        let sinU = sin(u)

        let x = (majorRadius + minorRadius * cosV) * cosU
        let y = minorRadius * sinV
        let z = (majorRadius + minorRadius * cosV) * sinU

        vertices.append(SIMD3<Float>(x, y, z))

        let normalX = cosV * cosU
        let normalY = sinV
        let normalZ = cosV * sinU
        normals.append(normalize(SIMD3<Float>(normalX, normalY, normalZ)))
      }
    }

    // Generate triangle indices for the torus surface
    for i in 0..<majorSegments {
      let i1 = (i + 1) % majorSegments

      for j in 0..<minorSegments {
        let j1 = (j + 1) % minorSegments

        let a = UInt32(i * minorSegments + j)
        let b = UInt32(i1 * minorSegments + j)
        let c = UInt32(i1 * minorSegments + j1)
        let d = UInt32(i * minorSegments + j1)

        indices.append(contentsOf: [a, b, c])
        indices.append(contentsOf: [a, c, d])
      }
    }

    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = MeshBuffers.Positions(vertices)
    meshDescriptor.normals = MeshBuffers.Normals(normals)
    meshDescriptor.primitives = .triangles(indices)

    do {
      let mesh = try MeshResource.generate(from: [meshDescriptor])
      print("🌅 MESH_GEN: Generated continuous torus with \(vertices.count) vertices, \(indices.count / 3) triangles")
      return mesh
    } catch {
      print("🌅 MESH_ERROR: Failed to generate torus mesh: \(error)")
      return MeshResource.generateBox(width: 0.1, height: 0.1, depth: 0.1)
    }
  }

  // PERFORMANCE FIX: Async horizon setup to avoid blocking main thread
  func setupHorizonLineAsync(in arView: ARView) {
    guard isDebugMode, showHorizonLineBinding, horizonEntity == nil, let baseAnchor = baseAnchor else {
      print("🌅 HORIZON_ASYNC: Skipping - debug: \(isDebugMode), showHorizonLine: \(showHorizonLineBinding), horizonEntity exists: \(horizonEntity != nil), baseAnchor exists: \(baseAnchor != nil)")
      return
    }

    // Mark setup in progress to prevent duplicate calls
    isHorizonSetupInProgress = true
    print("🌅 HORIZON_ASYNC: Starting async horizon mesh generation...")

    // Generate mesh on background thread
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      // Generate torus mesh on background thread (CPU-intensive)
      let majorRadius: Float = 30.0
      let minorRadius: Float = 0.05
      let torusMesh = self.generateTorusMesh(majorRadius: majorRadius, minorRadius: minorRadius)

      print("🌅 HORIZON_ASYNC: Mesh generated on background thread")

      // Create entity and add to scene on main thread
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let baseAnchor = self.baseAnchor else {
          self?.isHorizonSetupInProgress = false
          return
        }

        let horizonColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.5)
        let material = UnlitMaterial(color: horizonColor)
        let horizonRingEntity = ModelEntity(mesh: torusMesh, materials: [material])
        horizonRingEntity.name = "horizon_torus_continuous"
        horizonRingEntity.position = SIMD3<Float>(0, 0, 0)

        baseAnchor.addChild(horizonRingEntity)
        self.horizonEntity = horizonRingEntity
        self.isHorizonSetupInProgress = false

        print("🌅 HORIZON_ASYNC: ✅ Horizon line added to baseAnchor at position: \(horizonRingEntity.position)")
      }
    }
  }

  // Method to setup horizon line (DEPRECATED - Use setupHorizonLineAsync instead)
  func setupHorizonLine(in arView: ARView) {
    guard isDebugMode, showHorizonLineBinding, horizonEntity == nil, let baseAnchor = baseAnchor else {
      print("🌅 HORIZON: Skipping horizon setup - debug: \(isDebugMode), showHorizonLine: \(showHorizonLineBinding), horizonEntity exists: \(horizonEntity != nil), baseAnchor exists: \(baseAnchor != nil)")
      return
    }

    print("⚠️ HORIZON: WARNING - Using synchronous setup (should use setupHorizonLineAsync)")

    horizonEntity = createHorizonLineEntity()

    guard let horizon = horizonEntity else { return }

    horizon.position = SIMD3<Float>(0, 0, 0)
    baseAnchor.addChild(horizon)

    print("🌅 HORIZON: Horizon line added to baseAnchor at position: \(horizon.position)")
  }

  // Method to update horizon line position based on camera
  func updateHorizonLine(arView: ARView) {
    guard isDebugMode, showHorizonLineBinding, let horizon = horizonEntity,
          let cameraTransform = arView.session.currentFrame?.camera.transform else {
      if frameCounter % 300 == 0 {
        print("🌅 HORIZON_UPDATE: Skipped - debug: \(isDebugMode), showHorizonLine: \(showHorizonLineBinding), horizonEntity: \(horizonEntity != nil), camera: \(arView.session.currentFrame?.camera != nil)")
      }
      return
    }

    // Get camera position
    let cameraPosition = SIMD3<Float>(
      cameraTransform.columns.3.x,
      cameraTransform.columns.3.y,
      cameraTransform.columns.3.z
    )

    if let baseAnchor = baseAnchor {
      let cameraLocalY = baseAnchor.convert(position: cameraPosition, from: nil).y
      horizon.position = SIMD3<Float>(0, cameraLocalY, 0)
    }

    if frameCounter % 150 == 0 {
      print("🌅 HORIZON_UPDATE: Camera pos: \(cameraPosition)")
      print("🌅 HORIZON_UPDATE: Horizon local pos: \(horizon.position)")
      print("🌅 HORIZON_UPDATE: Horizon world pos: \(horizon.position(relativeTo: nil))")
      print("🌅 HORIZON_UPDATE: Horizon enabled: \(horizon.isEnabled)")
      print("🌅 HORIZON_UPDATE: Continuous torus entity: \(horizon.name ?? "unnamed")")
    }
  }

  // Method to toggle horizon line visibility
  func toggleHorizonLine() {
    let oldValue = showHorizonLineBinding
    showHorizonLineBinding.toggle()
    let newValue = showHorizonLineBinding

    print("🌅 HORIZON_TOGGLE: Changed from \(oldValue) to \(newValue)")
    print("🌅 HORIZON_TOGGLE: horizonEntity exists: \(horizonEntity != nil)")

    if showHorizonLineBinding {
      horizonEntity?.isEnabled = true
      print("🌅 HORIZON_TOGGLE: Horizon line enabled, entity enabled: \(horizonEntity?.isEnabled ?? false)")

      if horizonEntity == nil, let arView = arView {
        print("🌅 HORIZON_TOGGLE: No entity exists, trying to setup...")
        setupHorizonLine(in: arView)
      }
    } else {
      horizonEntity?.isEnabled = false
      print("🌅 HORIZON_TOGGLE: Horizon line disabled")
    }
  }

  // Method to ensure baseAnchor exists and check AR world alignment
  func ensureBaseAnchorExists(in arView: ARView) {
    print("⚓ ANCHOR_DEBUG: === Base Anchor Setup ===")

    // Check current AR session alignment
    if let frame = arView.session.currentFrame {
      let cameraTransform = frame.camera.transform
      print("⚓ ANCHOR_DEBUG: Camera transform: \(cameraTransform)")
      print("⚓ ANCHOR_DEBUG: Camera position: \(cameraTransform.columns.3)")

      if let heading = self.heading {
        print("⚓ ANCHOR_DEBUG: True heading: \(heading.trueHeading)°")
        print("⚓ ANCHOR_DEBUG: Magnetic heading: \(heading.magneticHeading)°")
        print("⚓ ANCHOR_DEBUG: Heading accuracy: \(heading.headingAccuracy)°")
      } else {
        print("⚓ ANCHOR_DEBUG: No heading available")
      }
    }

    if baseAnchor == nil {
      baseAnchor = AnchorEntity(world: .zero)
      arView.scene.addAnchor(baseAnchor!)
      print("⚓ ANCHOR_DEBUG: Created baseAnchor at world origin")
      print("⚓ ANCHOR_DEBUG: BaseAnchor transform: \(baseAnchor!.transform)")
      print("⚓ ANCHOR_DEBUG: BaseAnchor world position: \(baseAnchor!.position(relativeTo: nil))")

      setupHorizonLine(in: arView)
    } else {
      if baseAnchor?.scene == nil {
        arView.scene.addAnchor(baseAnchor!)
      }
      print("⚓ ANCHOR_DEBUG: BaseAnchor already exists")
      print("⚓ ANCHOR_DEBUG: BaseAnchor transform: \(baseAnchor!.transform)")
      print("⚓ ANCHOR_DEBUG: BaseAnchor world position: \(baseAnchor!.position(relativeTo: nil))")

      setupHorizonLine(in: arView)
    }
  }
}
