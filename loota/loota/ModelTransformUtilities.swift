// ModelTransformUtilities.swift
//
// Utilities for transforming 3D models from Blender coordinate system to ARKit coordinate system.
// Blender uses Z-up, ARKit uses Y-up. This requires a rotation transformation.

import RealityKit
import simd

/// Utilities for transforming 3D models between coordinate systems
enum ModelTransformUtilities {

    /// Applies the standard Blender-to-ARKit coordinate system conversion.
    ///
    /// Blender uses a Z-up coordinate system, while ARKit uses Y-up.
    /// This function applies a -90° rotation around the X-axis to convert between them.
    ///
    /// - Parameter entity: The ModelEntity to transform
    /// - Returns: The same entity with the coordinate system conversion applied
    @discardableResult
    static func applyBlenderToARKitConversion(_ entity: ModelEntity) -> ModelEntity {
        // Rotate -90° around X-axis to convert from Z-up (Blender) to Y-up (ARKit)
        let blenderToARKit = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        entity.transform.rotation = blenderToARKit
        return entity
    }

    /// Applies Blender-to-ARKit conversion and then an additional rotation.
    ///
    /// Use this when you need to both convert coordinate systems AND apply
    /// a specific orientation (e.g., rotate 90° to stand a card on edge).
    ///
    /// - Parameters:
    ///   - entity: The ModelEntity to transform
    ///   - additionalRotation: Rotation to apply after coordinate conversion
    /// - Returns: The same entity with both transformations applied
    @discardableResult
    static func applyBlenderToARKitConversion(
        _ entity: ModelEntity,
        thenApply additionalRotation: simd_quatf
    ) -> ModelEntity {
        // First apply Blender-to-ARKit conversion
        let blenderToARKit = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        // Combine rotations: conversion first, then additional rotation
        entity.transform.rotation = additionalRotation * blenderToARKit
        return entity
    }

    /// Creates a rotation quaternion for spinning around the Y-axis (vertical in ARKit).
    ///
    /// This is useful for creating spinning animations for coins, cards, etc.
    ///
    /// - Parameter angle: The rotation angle in radians
    /// - Returns: A quaternion representing rotation around the Y-axis
    static func verticalSpinRotation(angle: Float) -> simd_quatf {
        return simd_quatf(angle: angle, axis: [0, 1, 0])
    }
}
