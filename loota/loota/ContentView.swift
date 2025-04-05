//
//  ContentView.swift
//  loota
//
//  Created by Jared Goolsby on 3/28/25.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    // State variable to track the accumulated rotation angle
    @State private var totalRotationAngle: Float = 0.0

    var body: some View {
        RealityView { content in
            // Load the DollarSign model asynchronously
            do {
                let dollarSignEntity = try await Entity(named: "DollarSign", in: nil)

                // Name the entity for rotation lookup
                dollarSignEntity.name = "dollar_sign_model"

                // Position the single entity
                dollarSignEntity.position = [0, 0.2, 0] // Center position

                // --- Anchor Setup ---
                let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2)))
                anchor.addChild(dollarSignEntity) // Add the single model directly

                // Add anchor to the scene
                content.add(anchor)

                content.camera = .spatialTracking

            } catch {
                print("Error loading DollarSign model: \(error)")
            }

        } update: { content in
            // Find the single entity by name in the update closure
            guard let model = content.entities.first(where: { $0.name == "dollar_sign_model" }) else {
                // It might take a frame or two for the async loading to complete and the entity to be added.
                // print("Dollar sign model not found in update closure yet.")
                return
            }

            // Increment the total rotation angle
            totalRotationAngle += 0.01 // Adjust speed as needed

            // Calculate the new absolute orientation
            let newOrientation = simd_quatf(angle: totalRotationAngle, axis: [0, 1, 0]) // Rotate around Y axis

            // Set the model's orientation directly
            model.orientation = newOrientation

        }
        .edgesIgnoringSafeArea(.all)
    }

}

#Preview {
    ContentView()
}
