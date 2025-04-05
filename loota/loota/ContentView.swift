//
//  ContentView.swift
//  loota
//
//  Created by Jared Goolsby on 3/28/25.
//

import SwiftUI
import RealityKit

struct ContentView : View {

    var body: some View {
        RealityView { content in

            // Create a cube model
            let model = Entity()
            let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
            let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: true)
            model.components.set(ModelComponent(mesh: mesh, materials: [material]))
            // Position the cube ~2 feet (0.61 meters) above the anchor
            model.position = [0, 0.61, 0]

            // Create horizontal plane anchor for the content
            let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))
            anchor.addChild(model)

            // Add the horizontal plane anchor to the scene
            content.add(anchor)

            // Animate the cube to rotate
            let rotation = FromToByAnimation<Transform>(
                from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
                to: Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])), // Rotate 360 degrees (2 * pi radians)
                duration: 5, // Over 5 seconds
                bindTarget: .transform,
                repeatMode: .repeat // Repeat indefinitely
            )

            if let animation = try? AnimationResource.generate(with: rotation) {
                model.playAnimation(animation)
            }

            content.camera = .spatialTracking

        }
        .edgesIgnoringSafeArea(.all)
    }

}

#Preview {
    ContentView()
}
