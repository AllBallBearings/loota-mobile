import ARKit
import Foundation
import QuartzCore
import RealityKit

extension ARViewContainer.Coordinator {
  @objc func updateRotation(displayLink: CADisplayLink) {
    let frameStartTime = CACurrentMediaTime()

    frameCounter += 1

    // Detect summoning button state changes
    if isSummoningActiveBinding != wasSummoningActive {
      if isDebugMode {
        print("🧙‍♂️ SUMMON_STATE: Button state changed: \(wasSummoningActive) → \(isSummoningActiveBinding)")
        print("🧙‍♂️ SUMMON_STATE: focusedEntity: \(focusedEntity != nil ? "exists" : "nil"), summoningEntity: \(summoningEntity != nil ? "exists" : "nil")")
      }
      if isSummoningActiveBinding {
        // Button was just pressed - start summoning
        startObjectSummoning()
      } else {
        // Button was just released - stop summoning
        stopObjectSummoning()
      }
      wasSummoningActive = isSummoningActiveBinding
    }

    fpsCounter += 1
    let elapsed = frameStartTime - fpsLastUpdate
    if elapsed >= 1.0 {
      currentFPS = Double(fpsCounter) / elapsed
      fpsCounter = 0
      fpsLastUpdate = frameStartTime

      if isDebugMode {
        print("📊 FPS: \(String(format: "%.1f", currentFPS)) fps")
      }
    }

    if isDebugMode && frameCounter % 300 == 0 {
      if let camera = arView?.session.currentFrame?.camera {
        let state = trackingStateDescription(camera.trackingState)
        print("🎥 TRACKING_STATE_POLL: \(state)")
      } else {
        print("🎥 TRACKING_STATE_POLL: no camera frame")
      }
    }

    guard !coinEntities.isEmpty else {
      if isDebugMode && frameCounter % 600 == 0 {
        print("⚠️ UPDATE_ROTATION: Skipped - no coinEntities")
      }
      return
    }

    let focusUpdateInterval = isPerformanceMode ? 12 : 6
    let nearestUpdateInterval = isPerformanceMode ? 18 : 9
    let horizonUpdateInterval = isPerformanceMode ? 30 : 15

    let shouldRunFocus = frameCounter % focusUpdateInterval == 0
    let shouldRunNearest = frameCounter % nearestUpdateInterval == 0
    let shouldRunHorizon = frameCounter % horizonUpdateInterval == 0

    if shouldRunFocus {
      updateFocusDetection()
    }

    if shouldRunNearest {
      updateNearestLoot()
    }

    if let arView = arView {
      let shouldShowHorizon = isDebugMode && showHorizonLineBinding

      if shouldShowHorizon && horizonEntity == nil && !isHorizonSetupInProgress {
        setupHorizonLineAsync(in: arView)
      }

      if shouldShowHorizon && shouldRunHorizon {
        updateHorizonLine(arView: arView)
      }

      if let horizon = horizonEntity {
        horizon.isEnabled = shouldShowHorizon
        if frameCounter % 600 == 0 {
          print("🌅 HORIZON_VISIBILITY: debug=\(isDebugMode), showHorizonLineBinding=\(showHorizonLineBinding), entity.isEnabled=\(horizon.isEnabled)")
        }
      }
    }

    // Bobbing and spinning animation for coins
    let bobHeight: Float = 0.3048  // 1 foot in meters
    let bobCycleDuration: Float = 2.0  // seconds for one complete bob cycle (up and down)
    let deltaTime = Float(displayLink.duration)
    animationTime += deltaTime

    // Calculate bob position using sine wave (0 to 1 to 0 to -1 to 0)
    let bobPhase = animationTime / bobCycleDuration * 2.0 * .pi
    let bobOffset = sin(bobPhase) * bobHeight / 2.0  // Half height for amplitude

    // Calculate spin rotation - half spin (π radians) per bob cycle
    // When bobPhase goes from 0 to 2π, spin goes from 0 to π (half rotation)
    let spinAngle = (animationTime / bobCycleDuration) * .pi

    for entity in coinEntities {
      guard !collectedEntities.contains(entity) else { continue }
      guard entity != summoningEntity else { continue }  // Don't animate summoning entities

      // Apply spin rotation around world Y-axis (vertical)
      // spinRotation * baseRotation applies spin in world space first
      let spinRotation = simd_quatf(angle: spinAngle, axis: [0, 1, 0])
      let baseRotation = baseOrientations[entity] ?? simd_quatf(angle: 0, axis: [0, 1, 0])
      entity.transform.rotation = spinRotation * baseRotation

      // Apply bobbing to the entity's local position
      entity.position.y = bobOffset
    }

    // MARK: - Summoning Movement
    // Move summoning entity toward camera when button is held
    // Debug: Log when button is held but no entity is being summoned
    if isSummoningActiveBinding && summoningEntity == nil && isDebugMode && frameCounter % 120 == 0 {
      print("🧙‍♂️ SUMMON_MOVE: ⚠️ Button held but summoningEntity is nil")
      print("🧙‍♂️ SUMMON_MOVE: focusedEntity=\(focusedEntity != nil ? "exists" : "nil"), coinEntities.count=\(coinEntities.count)")
    }

    if isSummoningActiveBinding, let entity = summoningEntity {
      // Log when movement conditions are checked
      if isDebugMode && frameCounter % 120 == 0 {
        print("🧙‍♂️ SUMMON_MOVE: Movement loop active - checking arView and camera...")
      }

      guard let arView = arView else {
        if isDebugMode && frameCounter % 60 == 0 {
          print("🧙‍♂️ SUMMON_MOVE: ❌ arView is nil - cannot move entity!")
        }
        return
      }

      guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
        if isDebugMode && frameCounter % 60 == 0 {
          print("🧙‍♂️ SUMMON_MOVE: ❌ Camera transform unavailable - cannot track position!")
        }
        return
      }

      let cameraPosition = SIMD3<Float>(
        cameraTransform.columns.3.x,
        cameraTransform.columns.3.y,
        cameraTransform.columns.3.z)

      let entityPosition = entity.position(relativeTo: nil)
      let toCamera = cameraPosition - entityPosition
      let distance = simd_length(toCamera)

      // Debug: Log detailed position info on first frame and periodically
      if isDebugMode && frameCounter % 30 == 0 {
        let pinId = entityToPinId[entity] ?? "unknown"
        print("🧙‍♂️ SUMMON_MOVE: entity=\(pinId.prefix(8)), dist=\(String(format: "%.2f", distance))m")
        print("🧙‍♂️ SUMMON_MOVE: entityPos=(\(String(format: "%.2f", entityPosition.x)), \(String(format: "%.2f", entityPosition.y)), \(String(format: "%.2f", entityPosition.z)))")
        print("🧙‍♂️ SUMMON_MOVE: cameraPos=(\(String(format: "%.2f", cameraPosition.x)), \(String(format: "%.2f", cameraPosition.y)), \(String(format: "%.2f", cameraPosition.z)))")
      }

      // Check if entity has reached collection threshold
      let summonedCollectionDistance: Float = 0.8
      if distance < summonedCollectionDistance {
        // Entity reached user - trigger auto collection
        if isDebugMode {
          print("🧙‍♂️ SUMMON_MOVE: ✅ Entity reached collection threshold at \(String(format: "%.2f", distance))m (threshold: \(summonedCollectionDistance)m)")
          print("🧙‍♂️ SUMMON_MOVE: Triggering autoCollectSummonedEntity...")
        }
        autoCollectSummonedEntity(entity)
      } else {
        // Move entity toward camera with easing
        let direction = simd_normalize(toCamera)

        // MARK: - Easing Function for Dramatic Movement
        // Calculate progress-based speed: slow start, accelerate as it gets closer
        var easedSpeed = summonSpeed
        if let originalDistance = originalSummonDistance {
          // Calculate progress from 0 (at original position) to 1 (at collection threshold)
          let distanceRemaining = max(distance - summonedCollectionDistance, 0)
          let totalTravelDistance = max(originalDistance - summonedCollectionDistance, 0.1)
          let progress = 1.0 - (distanceRemaining / totalTravelDistance)

          // Ease-in cubic function: starts very slow, dramatically accelerates
          // progress^3 gives us: 0.1 -> 0.001, 0.5 -> 0.125, 0.9 -> 0.729
          let easedProgress = progress * progress * progress

          // Speed ranges from minSpeed at start to maxSpeed at end
          let minSpeed: Float = 0.3  // Slow, dramatic start
          let maxSpeed: Float = 4.0  // Fast, dramatic finish
          easedSpeed = minSpeed + (maxSpeed - minSpeed) * easedProgress

          if isDebugMode && frameCounter % 60 == 0 {
            print("🧙‍♂️ SUMMON_EASING: progress=\(String(format: "%.0f", progress * 100))%, easedProgress=\(String(format: "%.3f", easedProgress)), speed=\(String(format: "%.2f", easedSpeed))m/s")
          }
        } else {
          if isDebugMode && frameCounter % 60 == 0 {
            print("🧙‍♂️ SUMMON_MOVE: ⚠️ originalSummonDistance is nil, using default speed: \(summonSpeed)m/s")
          }
        }

        let moveAmount = easedSpeed * deltaTime
        let newPosition = entityPosition + direction * moveAmount
        entity.setPosition(newPosition, relativeTo: nil)

        // Debug: Log movement details
        if isDebugMode && frameCounter % 60 == 0 {
          print("🧙‍♂️ SUMMON_MOVE: moveAmount=\(String(format: "%.4f", moveAmount))m, deltaTime=\(String(format: "%.4f", deltaTime))s")
          print("🧙‍♂️ SUMMON_MOVE: newPos=(\(String(format: "%.2f", newPosition.x)), \(String(format: "%.2f", newPosition.y)), \(String(format: "%.2f", newPosition.z)))")
        }

        // MARK: - Scaling Effect
        // Scale up entity as it approaches to create fill-screen effect
        // Scale increases from 1.0 at original distance to 3.0 at collection distance
        if let originalScale = originalEntityScale,
           let originalDistance = originalSummonDistance {
          // Calculate progress from 0 (at original position) to 1 (at collection threshold)
          let distanceRemaining = max(distance - summonedCollectionDistance, 0)
          let totalTravelDistance = max(originalDistance - summonedCollectionDistance, 0.1)
          let progress = 1.0 - (distanceRemaining / totalTravelDistance)

          // Scale from 1.0 to 3.0 as progress goes from 0 to 1
          let minScale: Float = 1.0
          let maxScale: Float = 3.0
          let scaleFactor = minScale + (maxScale - minScale) * progress

          // Apply uniform scale
          entity.scale = originalScale * scaleFactor

          if isDebugMode && frameCounter % 60 == 0 {
            print("🧙‍♂️ SUMMON_SCALE: progress=\(String(format: "%.0f", progress * 100))%, scale=\(String(format: "%.2f", scaleFactor))x")
          }
        } else {
          if isDebugMode && frameCounter % 120 == 0 {
            print("🧙‍♂️ SUMMON_SCALE: ⚠️ Missing originalScale or originalDistance - skipping scale effect")
          }
        }
      }
    }

    let collectionCheckInterval = isPerformanceMode ? 6 : 3
    let shouldCheckCollection = isSummoningActiveBinding || (frameCounter % collectionCheckInterval == 0)
    if !shouldCheckCollection {
      return
    }

    guard let arView = arView,
      let cameraTransform = arView.session.currentFrame?.camera.transform
    else { return }
    let cameraPosition = SIMD3<Float>(
      cameraTransform.columns.3.x,
      cameraTransform.columns.3.y,
      cameraTransform.columns.3.z)

    if isDebugMode && frameCounter % 300 == 0 && isSummoningActiveBinding {
      print("🔍 COLLECTION_DEBUG: Anchors: \(anchors.count), Entities: \(coinEntities.count)")
    }

    let maxCollectionChecksPerFrame = isPerformanceMode ? 5 : 15
    var checksPerformed = 0

    for index in anchors.indices.reversed() {
      if checksPerformed >= maxCollectionChecksPerFrame && !isSummoningActiveBinding {
        break
      }
      checksPerformed += 1
      guard index < coinEntities.count else {
        print("⚠️ COLLECTION_DEBUG: Index \(index) out of bounds for coinEntities (count: \(coinEntities.count))")
        continue
      }

      let anchor = anchors[index]
      let entity = coinEntities[index]
      let entityWorldPosition = entity.position(relativeTo: nil)

      let distance = simd_distance(cameraPosition, entityWorldPosition)

      let normalCollectionDistance: Float = 0.25
      let summonedCollectionDistance: Float = 0.8
      let isSummonedObject = (entity == summoningEntity)
      let collectionThreshold =
        isSummonedObject ? summonedCollectionDistance : normalCollectionDistance

      if isDebugMode && isSummonedObject && frameCounter % 120 == 0 {
        print("🎯 SUMMONED: Dist: \(distance)m, Threshold: \(collectionThreshold)m")
      }

      if distance < collectionThreshold {
        if isSummonedObject {
          continue
        }

        collectedEntities.insert(entity)
        hideLabelsForEntity(entity, anchor: anchor)

        playCoinSound()

        let pinId = entityToPinId[entity] ?? "unknown"
        print("🪙 COLLECTION: Collected \(pinId.prefix(8)) at dist: \(distance)m")

        anchor.removeFromParent()

        anchors.remove(at: index)
        let removedEntity = coinEntities.remove(at: index)
        baseOrientations.removeValue(forKey: removedEntity)

        if currentHuntType == .geolocation && index < objectLocations.count {
          objectLocations.remove(at: index)
        }

        entityToPinId.removeValue(forKey: removedEntity)

        onCoinCollected?(pinId)
      }
    }
  }

  // MARK: - Nearest Loot Tracking for 2D Compass Needle
  private func updateNearestLoot() {
    guard let arView = arView, let camera = arView.session.currentFrame?.camera else { return }

    let cameraTransform = camera.transform
    let cameraPosition = SIMD3<Float>(
      cameraTransform.columns.3.x,
      cameraTransform.columns.3.y,
      cameraTransform.columns.3.z
    )

    var nearestEntity: ModelEntity?
    var nearestDistance: Float = .infinity

    for entity in coinEntities {
      let entityPosition = entity.position(relativeTo: nil)
      let distance = simd_distance(cameraPosition, entityPosition)
      if distance < nearestDistance {
        nearestDistance = distance
        nearestEntity = entity
      }
    }

    guard let nearest = nearestEntity else {
      nearestLootDistanceBinding = nil
      nearestLootDirectionBinding = 0
      return
    }

    nearestLootDistanceBinding = nearestDistance

    let entityWorldPosition = nearest.position(relativeTo: nil)
    let toEntity = entityWorldPosition - cameraPosition

    let worldUp = SIMD3<Float>(0, 1, 0)
    var toEntityFlat = toEntity - simd_dot(toEntity, worldUp) * worldUp
    var forwardVector = SIMD3<Float>(
      -cameraTransform.columns.2.x,
      -cameraTransform.columns.2.y,
      -cameraTransform.columns.2.z
    )
    var forwardFlat = forwardVector - simd_dot(forwardVector, worldUp) * worldUp
    var rightFlat = simd_cross(forwardFlat, worldUp)

    if simd_length_squared(toEntityFlat) < 1e-6 {
      toEntityFlat = SIMD3<Float>(0, 0, -1)
    } else {
      toEntityFlat = normalize(toEntityFlat)
    }

    if simd_length_squared(forwardFlat) < 1e-6 {
      forwardFlat = SIMD3<Float>(0, 0, -1)
    } else {
      forwardFlat = normalize(forwardFlat)
    }

    if simd_length_squared(rightFlat) < 1e-6 {
      rightFlat = SIMD3<Float>(1, 0, 0)
    } else {
      rightFlat = normalize(rightFlat)
    }

    let xComponent = simd_dot(toEntityFlat, rightFlat)
    let zComponent = simd_dot(toEntityFlat, forwardFlat)
    let angle = atan2(xComponent, zComponent)

    if angle.isFinite {
      nearestLootDirectionBinding = angle
    }

    if frameCounter % 60 == 0 {
      print("🧭 COMPASS: Nearest at \(nearestDistance)m, angle: \(angle * 180 / .pi)°")
    }
  }
}
