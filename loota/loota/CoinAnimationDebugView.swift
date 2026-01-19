// CoinAnimationDebugView.swift
// Simple debug view to test CoinSmooth USDZ animation without AR

import SwiftUI
import RealityKit
import Combine
import UIKit

struct CoinAnimationDebugView: View {
  var body: some View {
    VStack {
      Text("CoinSmooth Animation Debug")
        .font(.title)
        .padding()

      Text("Testing USDZ animation playback")
        .font(.subheadline)
        .foregroundColor(.gray)

      // RealityKit view showing the coin model
      CoinDebugARView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
  }
}

struct CoinDebugARView: UIViewRepresentable {
  func makeUIView(context: Context) -> ARView {
    let arView = ARView(frame: .zero)

    // Simple camera setup without AR tracking
    arView.environment.background = .color(.black)

    // Create anchor for the coin
    let anchor = AnchorEntity(world: [0, 0, -1]) // 1 meter in front

    // Load the CoinSmooth model using Entity.load (better for Blender exports)
    print("🪙 DEBUG: Loading CoinSmooth model using Entity.load...")

    Entity.loadAsync(named: "CoinSmooth")
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            print("✅ DEBUG: Entity.load completed")
          case .failure(let error):
            print("❌ DEBUG: Entity.load failed: \(error)")
          }
        },
        receiveValue: { loadedEntity in
          print("✅ DEBUG: Entity loaded successfully")
          print("🪙 DEBUG: Entity name: '\(loadedEntity.name)'")
          print("🪙 DEBUG: Entity type: \(type(of: loadedEntity))")
          print("🪙 DEBUG: Children count: \(loadedEntity.children.count)")

          // Log full entity hierarchy
          logEntityHierarchy(entity: loadedEntity, depth: 0)

          // Try to find animations in the scene
          print("🎬 DEBUG: Checking scene for animations...")
          if let scene = loadedEntity as? Entity {
            print("🎬 DEBUG: Scene available animations: \(scene.availableAnimations.count)")
            for animation in scene.availableAnimations {
              print("  🎬 Scene animation: '\(animation.name ?? "unnamed")'")
            }
          }

          // Scale the model for better visibility
          loadedEntity.scale = SIMD3<Float>(repeating: 0.3)
          loadedEntity.position = [0, 0, 0]

          // Try to play animations recursively
          print("🎬 DEBUG: Searching for animations in hierarchy...")
          playAllAnimations(entity: loadedEntity, depth: 0)

          // Try to play scene-level animations
          if !loadedEntity.availableAnimations.isEmpty {
            print("🎬 DEBUG: Playing scene-level animations")
            for animation in loadedEntity.availableAnimations {
              loadedEntity.playAnimation(animation.repeat())
            }
          }

          // Add to scene
          anchor.addChild(loadedEntity)
          arView.scene.addAnchor(anchor)

          print("✅ DEBUG: Entity added to scene")
        }
      )
      .store(in: &context.coordinator.cancellables)

    return arView
  }

  func updateUIView(_ uiView: ARView, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    var cancellables: Set<AnyCancellable> = []
  }

  // Helper functions
  private func logEntityHierarchy(entity: Entity, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    var info = "\(indent)📦 Entity: '\(entity.name)'"

    if let modelEntity = entity as? ModelEntity {
      info += " [ModelEntity]"
      if !modelEntity.availableAnimations.isEmpty {
        info += " ✅ Has \(modelEntity.availableAnimations.count) animation(s)"
      } else {
        info += " ❌ No animations"
      }
    }

    print(info)

    // Print animation details
    if let modelEntity = entity as? ModelEntity {
      for (index, animation) in modelEntity.availableAnimations.enumerated() {
        print("\(indent)  🎬 Animation \(index + 1): '\(animation.name ?? "unnamed")' - duration: \(animation.definition.duration)s")
      }
    }

    // Recurse through children
    for child in entity.children {
      logEntityHierarchy(entity: child, depth: depth + 1)
    }
  }

  private func playAllAnimations(entity: Entity, depth: Int) {
    let indent = String(repeating: "  ", count: depth)

    if let modelEntity = entity as? ModelEntity {
      if !modelEntity.availableAnimations.isEmpty {
        print("\(indent)🎬 DEBUG: Found \(modelEntity.availableAnimations.count) animation(s) on '\(entity.name)'")

        for (index, animation) in modelEntity.availableAnimations.enumerated() {
          print("\(indent)🎬 DEBUG: Playing animation \(index + 1): '\(animation.name ?? "unnamed")'")
          let controller = modelEntity.playAnimation(animation.repeat())
          print("\(indent)🎬 DEBUG: Animation controller created, isPlaying: \(controller.isPlaying)")
        }
      } else {
        print("\(indent)⚠️ DEBUG: No animations found on '\(entity.name)'")
      }
    }

    // Recurse through children
    for child in entity.children {
      playAllAnimations(entity: child, depth: depth + 1)
    }
  }
}

// Preview
struct CoinAnimationDebugView_Previews: PreviewProvider {
  static var previews: some View {
    CoinAnimationDebugView()
  }
}
