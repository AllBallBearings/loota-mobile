// CoinEntity.swift

import RealityKit
import UIKit

/// Factory for creating a ModelEntity representing a coin (flat disc) standing on its edge.
enum CoinEntityFactory {
    static func makeCoin(radius: Float = 0.12, height: Float = 0.02, color: UIColor = .yellow) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: height, radius: radius)
        let material = SimpleMaterial(color: color, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        // Stand the coin on its edge (vertical)
        entity.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        return entity
    }
}
