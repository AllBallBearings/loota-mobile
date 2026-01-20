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
  private static var cachedCoinModel: ModelEntity?
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
    coinModelCancellable = ModelEntity.loadModelAsync(named: "MarioCoin")
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
          cachedCoinModel = model
          isLoadingCoinModel = false
          completion?(true)
        }
      )
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

  /// Creates a coin using the CoinPlain.usdz 3D model
  static func makeCoin(
    radius: Float = 0.12,
    height: Float = 0.02,
    color: UIColor = .yellow,
    style: CoinStyle = .classic
  ) -> ModelEntity {
    if let cachedModel = cachedCoinModel {
      // Clone the cached model to avoid shared state.
      let coinModel = cachedModel.clone(recursive: true)

      // Scale to match the approximate size of the original coin
      // The original coin had a radius of 0.12m and height of 0.02m
      // We'll scale the model to achieve similar visual size
      coinModel.scale = SIMD3<Float>(repeating: 0.12)
      coinModel.name = "coin_model"

      // Keep the USDZ model's authored orientation.

      // Z-axis rotation (spinning) will be applied in ARViewContainer.

      return coinModel
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
