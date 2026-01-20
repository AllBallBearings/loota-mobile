import Foundation
import RealityKit
import UIKit

extension ARViewContainer.Coordinator {
  // MARK: - Focus Detection

  func setupFocusDetection() {
    print("🎯 FOCUS_DETECTION: Setting up loot focus detection")
    // Defer state modification to avoid "modifying state during view update" warning
    // This happens because setupFocusDetection is called from init, which runs during
    // SwiftUI's makeCoordinator() call within the view update cycle
    DispatchQueue.main.async { [weak self] in
      self?.isSummoningActiveBinding = false
      self?.focusedLootIdBinding = nil
      print("🎯 FOCUS_DETECTION: Ready - aim at loot to focus")
    }
  }

  func updateFocusDetection() {
    guard let arView = arView, let camera = arView.session.currentFrame?.camera else { return }

    let now = Date()
    // Update focus detection 10 times per second
    guard now.timeIntervalSince(lastFocusUpdateTime) >= 0.1 else { return }
    lastFocusUpdateTime = now

    let cameraTransform = camera.transform
    let cameraPosition = SIMD3<Float>(
      cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

    let forwardVector = normalize(
      SIMD3<Float>(
        -cameraTransform.columns.2.x,
        -cameraTransform.columns.2.y,
        -cameraTransform.columns.2.z
      )
    )

    let focusConeAngle: Float = 8.0 * (.pi / 180.0)

    var centerEntity: ModelEntity? = nil
    var closestDistance: Float = Float.infinity
    var smallestAngle: Float = Float.infinity

    for entity in coinEntities {
      let entityWorldPosition = entity.position(relativeTo: nil)
      let toEntity = entityWorldPosition - cameraPosition
      let distance = simd_length(toEntity)

      guard distance <= focusRange else { continue }

      let direction = normalize(toEntity)
      let dotProduct = simd_dot(forwardVector, direction)
      let clampedDot = max(min(dotProduct, 1.0), -1.0)
      let angle = acos(clampedDot)

      guard angle <= focusConeAngle else { continue }

      if angle < smallestAngle || (abs(angle - smallestAngle) < 0.5 * (.pi / 180.0) && distance < closestDistance) {
        centerEntity = entity
        closestDistance = distance
        smallestAngle = angle
      }
    }

    let previousFocusedEntity = focusedEntity
    focusedEntity = centerEntity

    if let entity = centerEntity, let pinId = entityToPinId[entity] {
      focusedLootIdBinding = pinId
      focusedLootDistanceBinding = closestDistance
      if isDebugMode {
        if previousFocusedEntity != centerEntity {
          if let previousEntity = previousFocusedEntity {
            removeGlowEffect(from: previousEntity)
          }
          addGlowEffect(to: entity)
        }
      } else {
        if let previousEntity = previousFocusedEntity {
          removeGlowEffect(from: previousEntity)
        }
        removeGlowEffect(from: entity)
      }
    } else {
      focusedLootIdBinding = nil
      focusedLootDistanceBinding = nil
      if let previousEntity = previousFocusedEntity {
        removeGlowEffect(from: previousEntity)
      }
    }
  }

  // MARK: - Halo Effects

  private func addGlowEffect(to entity: ModelEntity) {
    removeGlowEffect(from: entity)

    let bounds = entity.visualBounds(relativeTo: entity)
    let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
    let baseDiameter = max(maxExtent * 1.3, 0.3)

    guard
      let outerMaterial = makeGlowMaterial(style: .outer),
      let innerMaterial = makeGlowMaterial(style: .inner)
    else {
      print("✨ GLOW: Failed to create glow materials")
      return
    }

    let outerPlane = ModelEntity(
      mesh: MeshResource.generatePlane(width: baseDiameter * 1.6, depth: baseDiameter * 1.6),
      materials: [outerMaterial]
    )
    outerPlane.name = "glow_outer_billboard"
    outerPlane.position = .zero

    let innerPlane = ModelEntity(
      mesh: MeshResource.generatePlane(width: baseDiameter, depth: baseDiameter),
      materials: [innerMaterial]
    )
    innerPlane.name = "glow_inner_billboard"
    innerPlane.position = .zero

    entity.addChild(outerPlane)
    entity.addChild(innerPlane)
    print("✨ GLOW: Added layered glow planes around focused loot")
  }

  private func removeGlowEffect(from entity: ModelEntity) {
    for child in entity.children {
      if child.name == "glow_outer_billboard" || child.name == "glow_inner_billboard" {
        child.removeFromParent()
        print("✨ GLOW: Removed glow effect")
      }
    }
  }

  private enum GlowStyle {
    case outer
    case inner
  }

  private static var cachedOuterGlowTexture: TextureResource?
  private static var cachedInnerGlowTexture: TextureResource?

  private func makeGlowMaterial(style: GlowStyle) -> UnlitMaterial? {
    guard let texture = Self.glowTexture(for: style) else { return nil }

    let tint = UIColor(red: 1.0, green: 0.88, blue: 0.3, alpha: style == .outer ? 0.35 : 0.6)
    var material = UnlitMaterial()
    material.color = .init(tint: tint, texture: .init(texture))
    return material
  }

  private static func glowTexture(for style: GlowStyle) -> TextureResource? {
    switch style {
    case .outer:
      if let texture = cachedOuterGlowTexture { return texture }
      guard let generated = generateRadialGlowTexture(innerAlpha: 0.75, outerAlpha: 0.0) else { return nil }
      cachedOuterGlowTexture = generated
      return generated
    case .inner:
      if let texture = cachedInnerGlowTexture { return texture }
      guard let generated = generateRadialGlowTexture(innerAlpha: 1.0, outerAlpha: 0.08) else { return nil }
      cachedInnerGlowTexture = generated
      return generated
    }
  }

  private static func generateRadialGlowTexture(innerAlpha: CGFloat, outerAlpha: CGFloat) -> TextureResource? {
    let size = CGSize(width: 256, height: 256)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let image = renderer.image { context in
      guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          UIColor(white: 1.0, alpha: innerAlpha).cgColor,
          UIColor(white: 1.0, alpha: outerAlpha).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
      ) else { return }

      let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
      context.cgContext.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: max(size.width, size.height) / 2.0,
        options: [.drawsAfterEndLocation]
      )
    }

    guard let cgImage = image.cgImage else { return nil }
    do {
      let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
      return texture
    } catch {
      print("✨ GLOW: Failed to generate texture: \(error)")
      return nil
    }
  }
}
