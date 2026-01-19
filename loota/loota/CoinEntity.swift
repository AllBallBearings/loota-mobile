// CoinEntity.swift

import Combine
import RealityKit
import UIKit

/// Available coin design styles with embossed edges
enum CoinStyle {
  case classic  // 10% rim width, subtle embossing
  case thickRim  // 15% rim width, prominent embossing
  case detailed  // Multi-layer design with depth
  case beveled  // Beveled edges for polished look
}

/// Factory for creating a ModelEntity representing a coin (flat disc) standing on its edge.
enum CoinEntityFactory {
  private static var cachedCoinModel: Entity?
  private static var coinModelCancellable: AnyCancellable?
  private static var isLoadingCoinModel = false
  private static var didFailLoadingCoinModel = false

  static var isCoinModelReady: Bool {
    return cachedCoinModel != nil
  }

  static var isCoinModelLoading: Bool {
    return isLoadingCoinModel
  }

  static var shouldDeferPlacementForCoinModel: Bool {
    return cachedCoinModel == nil && !didFailLoadingCoinModel
  }

  static func preloadCoinModel(completion: ((Bool) -> Void)? = nil) {
    if cachedCoinModel != nil {
      completion?(true)
      return
    }
    if isLoadingCoinModel || didFailLoadingCoinModel {
      completion?(false)
      return
    }

    isLoadingCoinModel = true
    // Use Entity.loadAsync to preserve USDZ animation tracks
    coinModelCancellable = Entity.loadAsync(named: "CoinSmooth")
      .sink(
        receiveCompletion: { completionResult in
          switch completionResult {
          case .finished:
            break
          case .failure(let error):
            print("❌ COIN_MODEL: Async load failed: \(error)")
            didFailLoadingCoinModel = true
            isLoadingCoinModel = false
            completion?(false)
          }
        },
        receiveValue: { model in
          print("🪙 COIN_MODEL: Loaded successfully")
          print("🪙 COIN_MODEL: Available animations: \(model.availableAnimations.count)")
          cachedCoinModel = model
          isLoadingCoinModel = false
          completion?(true)
        }
      )
  }

  // MARK: - Animation Helpers

  /// Starts any available animations on the entity and its children
  /// Call this AFTER the entity has been added to the scene
  static func startAnimations(on entity: Entity, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)

    // Check for animations on this entity (works for any Entity type, not just ModelEntity)
    if !entity.availableAnimations.isEmpty {
      print("\(indent)🎬 COIN_ANIM: Found \(entity.availableAnimations.count) animation(s) on '\(entity.name)'")
      for animation in entity.availableAnimations {
        // Play animation with repeat and store controller
        let controller = entity.playAnimation(animation.repeat())
        controller.resume()
        print("\(indent)🎬 COIN_ANIM: Playing '\(animation.name ?? "unnamed")' isPlaying: \(controller.isPlaying)")
      }
    }

    // Recursively start animations on children
    for child in entity.children {
      startAnimations(on: child, depth: depth + 1)
    }

    // At root level, report summary
    if depth == 0 {
      let totalAnimations = countAnimations(in: entity)
      print("🎬 COIN_ANIM: Started \(totalAnimations) total animation(s) in hierarchy")
    }
  }

  /// Count total animations in hierarchy
  private static func countAnimations(in entity: Entity) -> Int {
    var count = entity.availableAnimations.count
    for child in entity.children {
      count += countAnimations(in: child)
    }
    return count
  }

  /// Recursively finds the first ModelEntity in the entity hierarchy
  private static func findFirstModelEntity(in entity: Entity) -> ModelEntity? {
    if let modelEntity = entity as? ModelEntity {
      return modelEntity
    }

    for child in entity.children {
      if let found = findFirstModelEntity(in: child) {
        return found
      }
    }

    return nil
  }

  /// Adds a gentle floating/bobbing animation to the coin
  private static func addFloatingAnimation(to entity: ModelEntity) {
    // Create a subtle up-and-down floating motion
    let floatDistance: Float = 0.02 // 2cm up and down
    let duration: TimeInterval = 2.0 // 2 second cycle

    // Create transform from current position
    var transformUp = entity.transform
    transformUp.translation.y += floatDistance

    var transformDown = entity.transform
    transformDown.translation.y -= floatDistance

    // Create animation that moves from down -> center -> up -> center -> down
    let moveUp = FromToByAnimation(
      name: "floatUp",
      from: transformDown,
      to: transformUp,
      duration: duration / 2,
      timing: .easeInOut,
      isAdditive: false,
      bindTarget: .transform
    )

    let moveDown = FromToByAnimation(
      name: "floatDown",
      from: transformUp,
      to: transformDown,
      duration: duration / 2,
      timing: .easeInOut,
      isAdditive: false,
      bindTarget: .transform
    )

    // Create animation resources from the animations
    do {
      let moveUpResource = try AnimationResource.generate(with: moveUp)
      let moveDownResource = try AnimationResource.generate(with: moveDown)

      // Create animation group that repeats
      let floatAnimation = try AnimationResource.sequence(with: [moveUpResource, moveDownResource])

      entity.playAnimation(floatAnimation.repeat())
      print("🎬 COIN_ANIMATION: Added programmatic floating animation")
    } catch {
      print("⚠️ COIN_ANIMATION: Failed to create floating animation: \(error)")
    }
  }

  private static func hasAnimations(in entity: Entity) -> Bool {
    if !entity.availableAnimations.isEmpty {
      return true
    }

    for child in entity.children {
      if hasAnimations(in: child) {
        return true
      }
    }

    return false
  }

  private static func stripAnchoring(from entity: Entity) {
    // Check for AnchoringComponent
    if entity.components[AnchoringComponent.self] != nil {
      print("🔧 STRIP_ANCHOR: Removing AnchoringComponent from '\(entity.name)'")
      entity.components[AnchoringComponent.self] = nil
    }

    for child in entity.children {
      stripAnchoring(from: child)
    }
  }

  /// Removes camera, lights, and other scene entities that shouldn't be in AR
  /// Returns list of removed entity names for logging
  private static func removeSceneEntities(from entity: Entity) -> [String] {
    var removed: [String] = []

    // Collect children to remove (can't modify while iterating)
    var childrenToRemove: [Entity] = []

    for child in entity.children {
      let name = child.name.lowercased()
      let typeName = String(describing: type(of: child))

      // Remove cameras
      if typeName.contains("Camera") || name.contains("camera") {
        childrenToRemove.append(child)
        removed.append("Camera: '\(child.name)'")
        continue
      }

      // Remove lights/sun entities (we'll use AR scene lighting)
      if name.contains("sun") || name.contains("light") || name.contains("env_light") {
        childrenToRemove.append(child)
        removed.append("Light: '\(child.name)'")
        continue
      }

      // Recursively clean children
      let childRemoved = removeSceneEntities(from: child)
      removed.append(contentsOf: childRemoved)
    }

    // Remove collected entities
    for child in childrenToRemove {
      child.removeFromParent()
    }

    return removed
  }

  private static func findModelEntity(named name: String, in entity: Entity) -> ModelEntity? {
    if let modelEntity = entity as? ModelEntity, modelEntity.name == name {
      return modelEntity
    }

    for child in entity.children {
      if let found = findModelEntity(named: name, in: child) {
        return found
      }
    }

    return nil
  }

  private static func reparentChildrenToNewRoot(_ entity: Entity) -> Entity {
    let newRoot = Entity()
    for child in entity.children {
      newRoot.addChild(child)
    }
    return newRoot
  }

  /// Logs the entity hierarchy for debugging
  private static func logEntityHierarchy(entity: Entity, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    var info = "\(indent)📦 Entity: '\(entity.name)'"

    if let modelEntity = entity as? ModelEntity {
      info += " [ModelEntity]"
      if !modelEntity.availableAnimations.isEmpty {
        info += " ✅ \(modelEntity.availableAnimations.count) animation(s)"
        for animation in modelEntity.availableAnimations {
          print("\(indent)  🎬 Animation: '\(animation.name ?? "unnamed")'")
        }
      }
    }

    print(info)

    for child in entity.children {
      logEntityHierarchy(entity: child, depth: depth + 1)
    }
  }

  /// Recursively searches for and plays all animations in the entity hierarchy
  private static func playAnimationsRecursively(entity: Entity, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)

    // Check for animations on this entity
    if let modelEntity = entity as? ModelEntity {
      if !modelEntity.availableAnimations.isEmpty {
        print("\(indent)🎬 COIN_ANIMATION: Found \(modelEntity.availableAnimations.count) animation(s) on entity '\(entity.name)'")

        // Play all animations found on this entity
        for (index, animation) in modelEntity.availableAnimations.enumerated() {
          print("\(indent)🎬 COIN_ANIMATION: Playing animation \(index + 1): '\(animation.name ?? "unnamed")' on loop")
          modelEntity.playAnimation(animation.repeat())
        }
      } else if depth == 0 {
        print("\(indent)⚠️ COIN_ANIMATION: No animations on root entity")
      }
    }

    // Recursively check all children
    for child in entity.children {
      playAnimationsRecursively(entity: child, depth: depth + 1)
    }

    // At root level, print summary
    if depth == 0 {
      let totalChildren = countChildren(entity: entity)
      print("🎬 COIN_ANIMATION: Searched \(totalChildren + 1) entities in hierarchy")
    }
  }

  /// Helper to count total children in hierarchy
  private static func countChildren(entity: Entity) -> Int {
    var count = entity.children.count
    for child in entity.children {
      count += countChildren(entity: child)
    }
    return count
  }

  // MARK: - Cylinder Mesh Generator (iOS 16+ compatible)

  /// Generates a cylinder mesh compatible with iOS 16.0+
  private static func generateCylinderMesh(height: Float, radius: Float) -> MeshResource {
    let segments = 32  // Number of segments around the cylinder
    var vertices: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    let halfHeight = height / 2.0

    // Generate vertices for top and bottom circles
    for i in 0...segments {
      let angle = Float(i) * 2.0 * .pi / Float(segments)
      let x = radius * cos(angle)
      let z = radius * sin(angle)

      // Top circle
      vertices.append(SIMD3<Float>(x, halfHeight, z))
      normals.append(normalize(SIMD3<Float>(x, 0, z)))

      // Bottom circle
      vertices.append(SIMD3<Float>(x, -halfHeight, z))
      normals.append(normalize(SIMD3<Float>(x, 0, z)))
    }

    // Generate side faces
    for i in 0..<segments {
      let topLeft = UInt32(i * 2)
      let bottomLeft = UInt32(i * 2 + 1)
      let topRight = UInt32((i + 1) * 2)
      let bottomRight = UInt32((i + 1) * 2 + 1)

      // First triangle
      indices.append(contentsOf: [topLeft, bottomLeft, topRight])
      // Second triangle
      indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
    }

    // Add top cap center vertex
    let topCenterIndex = UInt32(vertices.count)
    vertices.append(SIMD3<Float>(0, halfHeight, 0))
    normals.append(SIMD3<Float>(0, 1, 0))

    // Add bottom cap center vertex
    let bottomCenterIndex = UInt32(vertices.count)
    vertices.append(SIMD3<Float>(0, -halfHeight, 0))
    normals.append(SIMD3<Float>(0, -1, 0))

    // Add top cap triangles
    for i in 0..<segments {
      let current = UInt32(i * 2)
      let next = UInt32((i + 1) * 2)
      indices.append(contentsOf: [topCenterIndex, next, current])
    }

    // Add bottom cap triangles
    for i in 0..<segments {
      let current = UInt32(i * 2 + 1)
      let next = UInt32((i + 1) * 2 + 1)
      indices.append(contentsOf: [bottomCenterIndex, current, next])
    }

    // Create mesh descriptor
    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = MeshBuffers.Positions(vertices)
    meshDescriptor.normals = MeshBuffers.Normals(normals)
    meshDescriptor.primitives = .triangles(indices)

    do {
      return try MeshResource.generate(from: [meshDescriptor])
    } catch {
      print("❌ Failed to generate cylinder mesh: \(error)")
      // Fallback to a simple box
      return MeshResource.generateBox(size: SIMD3<Float>(radius * 2, height, radius * 2))
    }
  }

  /// Creates a coin using the CoinSmooth.usdz 3D model
  static func makeCoin(
    radius: Float = 0.12,
    height: Float = 0.02,
    color: UIColor = .yellow,
    style: CoinStyle = .classic
  ) -> ModelEntity {
    // TEMPORARY: Skip USDZ and use procedural coin to test AR tracking
    // Set to true to use USDZ, false to use simple procedural coin
    let useUSDZ = false

    if useUSDZ, let cachedModel = cachedCoinModel {
      // Clone the full scene to preserve USDZ animation tracks and hierarchy
      let coinEntity = cachedModel.clone(recursive: true)

      // Debug: Log entity type
      print("🪙 COIN_MODEL: Cloned entity type: \(type(of: coinEntity))")

      // CRITICAL: Remove camera, lights, and other scene entities that cause issues in AR
      let removedEntities = removeSceneEntities(from: coinEntity)
      if !removedEntities.isEmpty {
        print("🪙 COIN_MODEL: Removed scene entities: \(removedEntities.joined(separator: ", "))")
      }

      // Strip AnchoringComponent from the cloned entity (keeps hierarchy intact)
      stripAnchoring(from: coinEntity)

      // Create container to hold the coin
      let container = ModelEntity()
      container.name = "coin_container"

      // CRITICAL: If the root is an AnchorEntity, we need to extract its children
      // because AnchorEntity has built-in anchoring behavior that can't be disabled
      let entityToAdd: Entity
      if coinEntity is AnchorEntity {
        print("🪙 COIN_MODEL: Root is AnchorEntity - extracting children to new Entity")
        let newRoot = Entity()
        newRoot.name = "coin_root"

        // Copy transform from the anchor
        newRoot.transform = coinEntity.transform

        // Move all children to the new root
        let children = coinEntity.children.map { $0 }
        for child in children {
          newRoot.addChild(child)
        }

        // Copy animations to the new root - they need to be replayed
        let animations = coinEntity.availableAnimations
        entityToAdd = newRoot

        // Scale the model entity
        if let modelEntity = findModelEntity(named: "MarioCoin", in: newRoot)
          ?? findFirstModelEntity(in: newRoot)
        {
          modelEntity.scale = SIMD3<Float>(repeating: 0.24)
          print("🪙 COIN_MODEL: Scaled MarioCoin model entity to 0.24")
        }

        // Play animations on the new root
        for anim in animations {
          newRoot.playAnimation(anim.repeat())
          print("🪙 COIN_MODEL: Playing animation '\(anim.name ?? "unnamed")' on new root")
        }
      } else {
        // Not an AnchorEntity, use it directly
        entityToAdd = coinEntity

        // Scale the actual model entity, not the animation root
        if let modelEntity = findModelEntity(named: "MarioCoin", in: coinEntity)
          ?? findFirstModelEntity(in: coinEntity)
        {
          modelEntity.scale = SIMD3<Float>(repeating: 0.24)
          print("🪙 COIN_MODEL: Scaled MarioCoin model entity to 0.24")
        } else {
          coinEntity.scale = SIMD3<Float>(repeating: 0.24)
          print("🪙 COIN_MODEL: Scaled root entity to 0.24 (no model entity found)")
        }
      }

      // Add to container
      container.addChild(entityToAdd)

      // Debug: Log available animations
      print("🪙 COIN_MODEL: Entity animations available: \(entityToAdd.availableAnimations.count)")
      for anim in entityToAdd.availableAnimations {
        print("🪙 COIN_MODEL: Animation: '\(anim.name ?? "unnamed")'")
      }

      print("✅ COIN_MODEL: Cloned coin model")

      return container
    }

    if !isLoadingCoinModel && !didFailLoadingCoinModel {
      preloadCoinModel()
    }

    print("⚠️ COIN_MODEL: USDZ not ready yet - using procedural fallback")
    // Fallback to procedural generation if model isn't loaded yet
    return makeClassicCoin(radius: radius, height: height, color: color)
  }

  // MARK: - Classic Coin (20% rim width, prominent embossing)

  private static func makeClassicCoin(radius: Float, height: Float, color: UIColor) -> ModelEntity {
    let rimWidth = radius * 0.20  // 20% rim (increased from 10%)
    let centerRadius = radius - rimWidth
    let centerHeight = height * 0.5  // Center is 50% of total height (more pronounced)
    let rimHeight = height

    let container = ModelEntity()

    // Center disc (thinner for more visible edge)
    let centerMesh = generateCylinderMesh(height: centerHeight, radius: centerRadius)
    let centerMaterial = SimpleMaterial(color: color, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    // Outer rim (full height, more prominent)
    let rimMesh = generateCylinderMesh(height: rimHeight, radius: radius)
    let rimColor = color.withAlphaComponent(0.9)  // Slightly darker for better contrast
    let rimMaterial = SimpleMaterial(color: rimColor, isMetallic: true)
    let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMaterial])

    container.addChild(rimEntity)
    container.addChild(centerEntity)

    // Stand the coin on its edge (vertical) - rotated 90° around X-axis
    // Z-axis rotation will be applied in ARViewContainer for spinning
    container.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

    return container
  }

  // MARK: - Thick Rim Coin (15% rim width, prominent embossing)

  private static func makeThickRimCoin(radius: Float, height: Float, color: UIColor) -> ModelEntity
  {
    let rimWidth = radius * 0.15  // 15% rim
    let centerRadius = radius - rimWidth
    let centerHeight = height * 0.5  // Center is 50% of total height (thinner)
    let rimHeight = height

    let container = ModelEntity()

    // Center disc (thinner)
    let centerMesh = generateCylinderMesh(height: centerHeight, radius: centerRadius)
    let centerMaterial = SimpleMaterial(color: color, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    // Outer rim (full height, more prominent)
    let rimMesh = generateCylinderMesh(height: rimHeight, radius: radius)
    let rimColor = color.withAlphaComponent(0.9)
    let rimMaterial = SimpleMaterial(color: rimColor, isMetallic: true)
    let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMaterial])

    container.addChild(rimEntity)
    container.addChild(centerEntity)

    // Stand the coin on its edge (vertical) - rotated 90° around X-axis
    // Z-axis rotation will be applied in ARViewContainer for spinning
    container.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

    return container
  }

  // MARK: - Detailed Coin (Multi-layer with depth)

  private static func makeDetailedCoin(radius: Float, height: Float, color: UIColor) -> ModelEntity
  {
    let rimWidth = radius * 0.12  // 12% rim
    let centerRadius = radius - rimWidth
    let centerHeight = height * 0.55  // Center is 55% height
    let rimHeight = height
    let innerRimRadius = centerRadius + (rimWidth * 0.5)
    let innerRimHeight = height * 0.75

    let container = ModelEntity()

    // Outer rim (full height)
    let outerRimMesh = generateCylinderMesh(height: rimHeight, radius: radius)
    let outerRimColor = color.withAlphaComponent(0.85)
    let outerRimMaterial = SimpleMaterial(color: outerRimColor, isMetallic: true)
    let outerRimEntity = ModelEntity(mesh: outerRimMesh, materials: [outerRimMaterial])

    // Inner rim (mid height for stepped effect)
    let innerRimMesh = generateCylinderMesh(height: innerRimHeight, radius: innerRimRadius)
    let innerRimMaterial = SimpleMaterial(color: color, isMetallic: true)
    let innerRimEntity = ModelEntity(mesh: innerRimMesh, materials: [innerRimMaterial])

    // Center disc (thinnest)
    let centerMesh = generateCylinderMesh(height: centerHeight, radius: centerRadius)
    let centerColor = color.withAlphaComponent(1.0)
    let centerMaterial = SimpleMaterial(color: centerColor, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    container.addChild(outerRimEntity)
    container.addChild(innerRimEntity)
    container.addChild(centerEntity)

    // Stand the coin on its edge (vertical) - rotated 90° around X-axis
    // Z-axis rotation will be applied in ARViewContainer for spinning
    container.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

    return container
  }

  // MARK: - Beveled Coin (Beveled edges for polished look)

  private static func makeBeveledCoin(radius: Float, height: Float, color: UIColor) -> ModelEntity {
    let rimWidth = radius * 0.12  // 12% rim
    let centerRadius = radius - rimWidth
    let centerHeight = height * 0.6  // Center is 60% height
    let rimHeight = height
    let bevelRadius = centerRadius + (rimWidth * 0.7)
    let bevelHeight = height * 0.8

    let container = ModelEntity()

    // Outer rim (full height)
    let rimMesh = generateCylinderMesh(height: rimHeight, radius: radius)
    let rimColor = color.withAlphaComponent(0.9)
    let rimMaterial = SimpleMaterial(color: rimColor, isMetallic: true)
    let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMaterial])

    // Bevel layer (creates smooth transition)
    let bevelMesh = generateCylinderMesh(height: bevelHeight, radius: bevelRadius)
    let bevelColor = color.withAlphaComponent(0.95)
    let bevelMaterial = SimpleMaterial(color: bevelColor, isMetallic: true)
    let bevelEntity = ModelEntity(mesh: bevelMesh, materials: [bevelMaterial])

    // Center disc (thinner)
    let centerMesh = generateCylinderMesh(height: centerHeight, radius: centerRadius)
    let centerMaterial = SimpleMaterial(color: color, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    container.addChild(rimEntity)
    container.addChild(bevelEntity)
    container.addChild(centerEntity)

    // Stand the coin on its edge (vertical) - rotated 90° around X-axis
    // Z-axis rotation will be applied in ARViewContainer for spinning
    container.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

    return container
  }
}
