// GiftCardEntity.swift

import RealityKit
import UIKit

/// Factory for creating a ModelEntity representing a gift card with rounded edges.
/// Styled similar to an Amazon gift card (orange/amber color).
enum GiftCardEntityFactory {

    /// Creates a gift card entity (rounded rectangle, standing vertical)
    /// - Parameters:
    ///   - width: Width of the gift card (default: 0.18m, ~50% bigger than coin)
    ///   - height: Height of the gift card (default: 0.114m, maintains credit card ratio)
    ///   - thickness: Thickness of the card (default: 0.002m, thin like a real card)
    ///   - cornerRadius: Radius for rounded corners (default: 0.01m)
    ///   - primaryColor: Main card color (default: Amazon orange)
    ///   - accentColor: Border/accent color (default: darker orange)
    /// - Returns: A ModelEntity configured as a gift card
    static func makeGiftCard(
        width: Float = 0.18,
        height: Float = 0.114,
        thickness: Float = 0.002,
        cornerRadius: Float = 0.01,
        primaryColor: UIColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0), // Amazon orange
        accentColor: UIColor = UIColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1.0)   // Darker orange
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
        let borderInset: Float = 0.003 // 3mm inset from edge
        let border = createRoundedRectangle(
            width: width + borderInset,
            height: height + borderInset,
            thickness: borderThickness,
            cornerRadius: cornerRadius + borderInset/2,
            color: accentColor
        )

        // Add border first (behind), then card body (in front)
        container.addChild(border)
        container.addChild(cardBody)

        // Rotate to stand vertical (like a standing card)
        // First rotate 90° around X to make it vertical, then slight tilt for visual interest
        let verticalRotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        container.transform.rotation = verticalRotation

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
