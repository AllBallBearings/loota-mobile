import AVFoundation
import Foundation
import QuartzCore
import RealityKit
import UIKit

extension ARViewContainer.Coordinator {
  // MARK: - Object Summoning

  func startObjectSummoning() {
    if isDebugMode {
      print("🧙‍♂️ SUMMONING: Button summoning started")
    }

    guard let targetEntity = focusedEntity else {
      if isDebugMode {
        print("🧙‍♂️ SUMMONING: ❌ No focused loot to summon")
      }
      return
    }

    guard summoningEntity != targetEntity else {
      if isDebugMode {
        print("🧙‍♂️ SUMMONING: Already summoning this object")
      }
      return
    }

    let pinId = entityToPinId[targetEntity] ?? "unknown"
    let shortId = pinId.prefix(8)
    if isDebugMode {
      print("🧙‍♂️ SUMMONING: Starting summoning of loot ID:\(shortId)")
    }

    guard let arView = arView, let camera = arView.session.currentFrame?.camera else {
      if isDebugMode {
        print("🧙‍♂️ SUMMONING: ❌ No camera available")
      }
      return
    }
    let cameraPosition = SIMD3<Float>(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
    let entityPosition = targetEntity.position(relativeTo: nil)
    let distance = simd_distance(entityPosition, cameraPosition)

    if isDebugMode {
      print("🧙‍♂️ SUMMONING: ✅ Found center target entity at distance: \(distance) meters")
    }

    summoningEntity = targetEntity
    originalEntityPosition = targetEntity.position(relativeTo: nil)
    originalEntityScale = targetEntity.scale
    originalSummonDistance = distance
    summonStartTime = CACurrentMediaTime()

    if let entityIndex = coinEntities.firstIndex(of: targetEntity) {
      if isDebugMode {
        print("🧙‍♂️ SUMMONING: Target entity found at index \(entityIndex) in coinEntities")
      }
      if let pinId = entityToPinId[targetEntity] {
        if isDebugMode {
          print("🧙‍♂️ SUMMONING: Entity has pinId: \(pinId)")
        }
      } else {
        if isDebugMode {
          print("⚠️ SUMMONING: WARNING - Entity has no pinId mapping!")
        }
      }
    } else {
      if isDebugMode {
        print("⚠️ SUMMONING: ERROR - Target entity NOT found in coinEntities array!")
      }
    }

    if isDebugMode {
      print("🧙‍♂️ SUMMONING: Summoning state set - starting animation...")
      print("🧙‍♂️ SUMMONING: Current state - buttonActive: \(isSummoningActiveBinding), summoningEntity != nil: \(summoningEntity != nil)")
    }

    if isDebugMode {
      print("🧙‍♂️ SUMMONING: About to call animateObjectTowardsUser...")
    }
    animateObjectTowardsUser(targetEntity, cameraPosition: cameraPosition)
    if isDebugMode {
      print("🧙‍♂️ SUMMONING: animateObjectTowardsUser call completed")
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      if self.isDebugMode {
        print("🧙‍♂️ SUMMONING: 1s state check - buttonActive: \(self.isSummoningActiveBinding), entity exists: \(self.summoningEntity != nil)")
      }
    }
  }

  func stopObjectSummoning(keepCurrentPosition: Bool = false) {
    guard let entity = summoningEntity,
      let originalPosition = originalEntityPosition
    else {
      summoningEntity = nil
      originalEntityPosition = nil
      originalEntityScale = nil
      originalSummonDistance = nil
      summonStartTime = nil
      return
    }

    if keepCurrentPosition {
      // Keep entity at current position for better UX when button released early
      if isDebugMode {
        print("🧙‍♂️ SUMMONING: Object summoning stopped, keeping entity at current position")
      }
    } else {
      // Reset position and scale to original
      entity.setPosition(originalPosition, relativeTo: nil)

      if let originalScale = originalEntityScale {
        entity.scale = originalScale
      }

      if isDebugMode {
        print("🧙‍♂️ SUMMONING: Object summoning stopped, returned to original position and scale")
      }
    }

    summoningEntity = nil
    originalEntityPosition = nil
    originalEntityScale = nil
    originalSummonDistance = nil
    summonStartTime = nil
  }

  private func animateObjectTowardsUser(_ entity: ModelEntity, cameraPosition: SIMD3<Float>) {
    let entityPosition = entity.position(relativeTo: nil)
    let totalDistance = simd_distance(entityPosition, cameraPosition)

    if isDebugMode {
      print("🧙‍♂️ SUMMONING: Starting button-controlled summoning")
      print("🧙‍♂️ SUMMONING: Entity at: \(entityPosition), Camera at: \(cameraPosition)")
      print("🧙‍♂️ SUMMONING: Distance: \(totalDistance)m, Speed: \(summonSpeed)m/s")
    }

    summoningEntity = entity
    originalEntityPosition = entityPosition
    summonStartTime = CACurrentMediaTime()

    if isDebugMode {
      print("🧙‍♂️ SUMMONING: Summoning setup complete, object will move when button is held")
    }
  }

  func autoCollectSummonedEntity(_ entity: ModelEntity) {
    if isDebugMode {
      print("🎯 AUTO_COLLECT: Attempting auto-collection")
      print("🎯 AUTO_COLLECT: Current summoningEntity: \(summoningEntity?.debugDescription ?? "nil")")
      print("🎯 AUTO_COLLECT: Target entity: \(entity.debugDescription)")
      print("🎯 AUTO_COLLECT: Entities match: \(entity == summoningEntity)")
    }

    guard let pinId = entityToPinId[entity], pinId != "unknown" else {
      if isDebugMode {
        print("🎯 AUTO_COLLECT: No valid pin ID found for entity")
      }
      return
    }

    if isDebugMode {
      print("🎯 AUTO_COLLECT: Auto-collecting entity with pinId: \(pinId)")
    }

    guard let entityIndex = coinEntities.firstIndex(of: entity),
          let anchor = findAnchorForEntity(entity) else {
      if isDebugMode {
        print("🎯 AUTO_COLLECT: Could not find entity in arrays")
      }
      return
    }

    if isDebugMode {
      print("🎯 AUTO_COLLECT: Clearing summoning state to allow subsequent summoning")
    }
    summoningEntity = nil
    originalEntityPosition = nil
    originalEntityScale = nil
    originalSummonDistance = nil
    summonStartTime = nil

    collectedEntities.insert(entity)

    playCoinSound()
    hideLabelsForEntity(entity, anchor: anchor)

    anchor.removeFromParent()
    anchors.remove(at: entityIndex)
    coinEntities.remove(at: entityIndex)
    baseOrientations.removeValue(forKey: entity)
    if currentHuntType == .geolocation && entityIndex < objectLocations.count {
      objectLocations.remove(at: entityIndex)
    }
    entityToPinId.removeValue(forKey: entity)

    if isDebugMode {
      print("🎯 AUTO_COLLECT: Collection completed - triggering callback")
    }

    onCoinCollected?(pinId)
  }

  private func findAnchorForEntity(_ entity: ModelEntity) -> AnchorEntity? {
    for anchor in anchors {
      if anchor.children.contains(where: { child in
        if let modelEntity = child as? ModelEntity {
          return modelEntity == entity
        }
        return false
      }) {
        return anchor
      }
    }
    return nil
  }

  func hideLabelsForEntity(_ entity: ModelEntity, anchor: AnchorEntity) {
    for child in anchor.children {
      if child != entity {
        child.isEnabled = false
      }
    }
  }

  func playCoinSound() {
    guard let url = Bundle.main.url(forResource: "CoinPunch", withExtension: "mp3") else {
      print("❌ AUDIO: Missing CoinPunch.mp3 in app bundle")
      print("📁 AUDIO: Bundle path: \(Bundle.main.bundlePath)")
      return
    }

    print("✅ AUDIO: Found CoinPunch.mp3 at: \(url)")

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
      print("✅ AUDIO: Audio session configured")

      audioPlayer?.stop()

      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.volume = 1.0
      audioPlayer?.prepareToPlay()

      let didPlay = audioPlayer?.play() ?? false
      print("🔊 AUDIO: Play attempt - Success: \(didPlay), Duration: \(audioPlayer?.duration ?? 0)s")

      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
      print("📳 HAPTIC: Played haptic feedback for coin collection")
    } catch {
      print("❌ AUDIO: Failed to play CoinPunch sound: \(error)")
    }
  }
}
