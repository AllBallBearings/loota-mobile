// CoinEntity.swift

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

  /// Creates a coin using the CoinPlain.usdz 3D model
  static func makeCoin(
    radius: Float = 0.12,
    height: Float = 0.02,
    color: UIColor = .yellow,
    style: CoinStyle = .classic
  ) -> ModelEntity {
    do {
      // Load the CoinPlain.usdz model
      let coinModel = try ModelEntity.loadModel(named: "CoinPlain")

      // Scale to match the approximate size of the original coin
      // The original coin had a radius of 0.12m and height of 0.02m
      // We'll scale the model to achieve similar visual size
      coinModel.scale = SIMD3<Float>(repeating: 0.12)

      // Rotate the model to stand upright on its edge.
      // Blender (where the model was made) uses a Z-up coordinate system,
      // while RealityKit uses a Y-up system. A 90-degree rotation
      // around the X-axis corrects for this difference, making the coin stand vertically.
      coinModel.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

      // Z-axis rotation (spinning) will be applied in ARViewContainer.

      return coinModel
    } catch {
      print("❌ COIN_MODEL: Error loading CoinPlain.usdz: \(error)")
      print("❌ COIN_MODEL: Falling back to procedural coin generation")
      // Fallback to procedural generation if model fails to load
      return makeClassicCoin(radius: radius, height: height, color: color)
    }
  }

  // MARK: - Classic Coin (20% rim width, prominent embossing)

  private static func makeClassicCoin(radius: Float, height: Float, color: UIColor) -> ModelEntity {
    let rimWidth = radius * 0.20  // 20% rim (increased from 10%)
    let centerRadius = radius - rimWidth
    let centerHeight = height * 0.5  // Center is 50% of total height (more pronounced)
    let rimHeight = height

    let container = ModelEntity()

    // Center disc (thinner for more visible edge)
    let centerMesh = MeshResource.generateCylinder(height: centerHeight, radius: centerRadius)
    let centerMaterial = SimpleMaterial(color: color, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    // Outer rim (full height, more prominent)
    let rimMesh = MeshResource.generateCylinder(height: rimHeight, radius: radius)
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
    let centerMesh = MeshResource.generateCylinder(height: centerHeight, radius: centerRadius)
    let centerMaterial = SimpleMaterial(color: color, isMetallic: true)
    let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

    // Outer rim (full height, more prominent)
    let rimMesh = MeshResource.generateCylinder(height: rimHeight, radius: radius)
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
    let outerRimMesh = MeshResource.generateCylinder(height: rimHeight, radius: radius)
    let outerRimColor = color.withAlphaComponent(0.85)
    let outerRimMaterial = SimpleMaterial(color: outerRimColor, isMetallic: true)
    let outerRimEntity = ModelEntity(mesh: outerRimMesh, materials: [outerRimMaterial])

    // Inner rim (mid height for stepped effect)
    let innerRimMesh = MeshResource.generateCylinder(height: innerRimHeight, radius: innerRimRadius)
    let innerRimMaterial = SimpleMaterial(color: color, isMetallic: true)
    let innerRimEntity = ModelEntity(mesh: innerRimMesh, materials: [innerRimMaterial])

    // Center disc (thinnest)
    let centerMesh = MeshResource.generateCylinder(height: centerHeight, radius: centerRadius)
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
    let rimMesh = MeshResource.generateCylinder(height: rimHeight, radius: radius)
    let rimColor = color.withAlphaComponent(0.9)
    let rimMaterial = SimpleMaterial(color: rimColor, isMetallic: true)
    let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMaterial])

    // Bevel layer (creates smooth transition)
    let bevelMesh = MeshResource.generateCylinder(height: bevelHeight, radius: bevelRadius)
    let bevelColor = color.withAlphaComponent(0.95)
    let bevelMaterial = SimpleMaterial(color: bevelColor, isMetallic: true)
    let bevelEntity = ModelEntity(mesh: bevelMesh, materials: [bevelMaterial])

    // Center disc (thinner)
    let centerMesh = MeshResource.generateCylinder(height: centerHeight, radius: centerRadius)
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
