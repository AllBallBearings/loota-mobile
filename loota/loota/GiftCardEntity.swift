// GiftCardEntity.swift

import Combine
import RealityKit
import UIKit

/// Factory for creating a ModelEntity representing a gift card.
/// Uses AmazonGiftcard.usdz 3D model with procedural fallback.
enum GiftCardEntityFactory {
  private static var cachedGiftCardModel: ModelEntity?
  private static var giftCardModelCancellable: AnyCancellable?
  private static var isLoadingGiftCardModel = false
  private static var didFailLoadingGiftCardModel = false

  static var isGiftCardModelReady: Bool {
    return cachedGiftCardModel != nil
  }

  static var isGiftCardModelLoading: Bool {
    return isLoadingGiftCardModel
  }

  static var shouldDeferPlacementForGiftCardModel: Bool {
    return cachedGiftCardModel == nil && !didFailLoadingGiftCardModel
  }

  static func preloadGiftCardModel(completion: ((Bool) -> Void)? = nil) {
    if cachedGiftCardModel != nil {
      completion?(true)
      return
    }
    if isLoadingGiftCardModel || didFailLoadingGiftCardModel {
      completion?(false)
      return
    }

    isLoadingGiftCardModel = true
    giftCardModelCancellable = ModelEntity.loadModelAsync(named: "AmazonGiftcard")
      .sink(
        receiveCompletion: { completionResult in
          switch completionResult {
          case .finished:
            break
          case .failure(let error):
            print("❌ GIFTCARD_MODEL: Async load failed: \(error)")
            didFailLoadingGiftCardModel = true
            isLoadingGiftCardModel = false
            completion?(false)
          }
        },
        receiveValue: { model in
          // Reset rotation to identity on the cached model
          // This ensures clones start with correct orientation
          model.transform.rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
          cachedGiftCardModel = model
          isLoadingGiftCardModel = false
          completion?(true)
        }
      )
  }

  /// Creates a gift card using the AmazonGiftcard.usdz 3D model
  static func makeGiftCard() -> ModelEntity {
    if let cachedModel = cachedGiftCardModel {
      // Clone the cached model to avoid shared state
      let giftCardModel = cachedModel.clone(recursive: true)

      // Scale to appropriate size (adjust based on model's natural size)
      giftCardModel.scale = SIMD3<Float>(repeating: 0.12)
      giftCardModel.name = "giftcard_model"

      // Keep the USDZ model's authored orientation.
      // The test view confirms it is already upright without extra rotation.

      return giftCardModel
    }

    if !isLoadingGiftCardModel && !didFailLoadingGiftCardModel {
      preloadGiftCardModel()
    }

    print("⚠️ GIFTCARD_MODEL: USDZ not ready yet - using procedural fallback")
    // Fallback to procedural generation if model isn't loaded yet
    return makeProceduralGiftCard()
  }

  // MARK: - Procedural Fallback

  /// Creates a procedural gift card (rounded rectangle, standing vertical)
  private static func makeProceduralGiftCard(
    width: Float = 0.18,
    height: Float = 0.114,
    thickness: Float = 0.002,
    cornerRadius: Float = 0.01,
    primaryColor: UIColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
    accentColor: UIColor = UIColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1.0)
  ) -> ModelEntity {

    let container = ModelEntity()

    // Main card body (rounded rectangle)
    let cardBody = createRoundedRectangle(
      width: width,
      height: height,
      thickness: thickness,
      cornerRadius: cornerRadius,
      color: primaryColor
    )

    // Border/frame (slightly larger, creates outline effect)
    let borderThickness = thickness * 1.2
    let borderInset: Float = 0.003
    let border = createRoundedRectangle(
      width: width + borderInset,
      height: height + borderInset,
      thickness: borderThickness,
      cornerRadius: cornerRadius + borderInset / 2,
      color: accentColor
    )

    // Add border first (behind), then card body (in front)
    container.addChild(border)
    container.addChild(cardBody)

    // Note: Procedural geometry is already in ARKit coordinate system (Y-up)
    // Rotate 90° around X-axis to stand the card vertically on its edge
    let standVertical = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    container.transform.rotation = standVertical

    return container
  }

  // MARK: - Helper Methods

  /// Creates a rounded rectangle using a box with rounded corners
  private static func createRoundedRectangle(
    width: Float,
    height: Float,
    thickness: Float,
    cornerRadius: Float,
    color: UIColor
  ) -> ModelEntity {

    let material = SimpleMaterial(color: color, isMetallic: false)

    // Use a simple box with rounded corners
    // RealityKit's generateBox with cornerRadius creates smooth rounded edges
    let mesh = MeshResource.generateBox(
      width: width,
      height: thickness,
      depth: height,
      cornerRadius: cornerRadius
    )

    let entity = ModelEntity(mesh: mesh, materials: [material])
    return entity
  }
}
