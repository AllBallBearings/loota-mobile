import ARKit
import CoreLocation
import Foundation
import QuartzCore
import RealityKit
import UIKit

extension ARViewContainer.Coordinator {
  // CRITICAL FIX: Async object placement to prevent main thread blocking
  func placeObjectsAsync(arView: ARView) {
    if isDebugMode {
      print("🚀 ASYNC_PLACEMENT: Starting async placement")
    }

    guard let refLoc = self.referenceLocation else {
      if isDebugMode {
        print("🚀 ASYNC_PLACEMENT: No reference location")
      }
      return
    }

    self.clearAnchors()

    // Determine what to place based on hunt type
    switch self.currentHuntType {
    case .geolocation:
      guard !self.objectLocations.isEmpty else { return }
      if isDebugMode {
        print("🚀 ASYNC_PLACEMENT: Pre-cloning \(self.objectLocations.count) geolocation entities...")
      }
      self.statusMessage = "Preparing objects..."

      // CRITICAL FIX: Pre-clone all entities on background thread
      preCloneEntitiesForGeolocation(count: self.objectLocations.count) { [weak self] entities in
        guard let self = self else { return }
        if self.isDebugMode {
          print("✅ ASYNC_PLACEMENT: All entities pre-cloned, starting placement")
        }
        self.placeGeolocationObjectsWithPreclonedEntities(arView: arView, refLoc: refLoc, locations: self.objectLocations, entities: entities)
      }

    case .proximity:
      guard !self.proximityMarkers.isEmpty else { return }
      if isDebugMode {
        print("🚀 ASYNC_PLACEMENT: Pre-cloning \(self.proximityMarkers.count) proximity entities...")
      }
      self.statusMessage = "Preparing objects..."

      preCloneEntitiesForProximity(count: self.proximityMarkers.count) { [weak self] entities in
        guard let self = self else { return }
        if self.isDebugMode {
          print("✅ ASYNC_PLACEMENT: All entities pre-cloned, starting placement")
        }
        self.placeProximityObjectsWithPreclonedEntities(arView: arView, markers: self.proximityMarkers, entities: entities)
      }

    case .none:
      if isDebugMode {
        print("🚀 ASYNC_PLACEMENT: No hunt type")
      }
      self.statusMessage = "No hunt data loaded."
    case .some(let actualHuntType):
      if isDebugMode {
        print("🚀 ASYNC_PLACEMENT: Unhandled hunt type: \(actualHuntType)")
      }
      self.statusMessage = "Unsupported hunt type."
    }
  }

  // PRE-CLONE entities on background thread (this is the expensive part)
  private func preCloneEntitiesForGeolocation(count: Int, completion: @escaping ([ModelEntity?]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      var entities: [ModelEntity?] = []

      let startTime = CACurrentMediaTime()
      for index in 0..<count {
        let pin = index < self.pinData.count ? self.pinData[index] : nil
        let lootType = pin?.objectType ?? self.objectType

        // This is the SLOW part - do it on background thread
        let entity = self.createEntity(for: lootType)
        entities.append(entity)

        if index % 5 == 0, self.isDebugMode {
          print("🔧 PRE_CLONE: Cloned \(index + 1)/\(count) entities (\(String(format: "%.3f", CACurrentMediaTime() - startTime))s)")
        }
      }

      let totalTime = CACurrentMediaTime() - startTime
      if self.isDebugMode {
        print("✅ PRE_CLONE: All \(count) entities cloned in \(String(format: "%.3f", totalTime))s")
      }

      DispatchQueue.main.async {
        completion(entities)
      }
    }
  }

  private func preCloneEntitiesForProximity(count: Int, completion: @escaping ([ModelEntity?]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      var entities: [ModelEntity?] = []

      let startTime = CACurrentMediaTime()
      for index in 0..<count {
        let pin = index < self.pinData.count ? self.pinData[index] : nil
        let lootType = pin?.objectType ?? .coin

        let entity = self.createEntity(for: lootType)
        entities.append(entity)

        if index % 5 == 0, self.isDebugMode {
          print("🔧 PRE_CLONE: Cloned \(index + 1)/\(count) entities (\(String(format: "%.3f", CACurrentMediaTime() - startTime))s)")
        }
      }

      let totalTime = CACurrentMediaTime() - startTime
      if self.isDebugMode {
        print("✅ PRE_CLONE: All \(count) entities cloned in \(String(format: "%.3f", totalTime))s")
      }

      DispatchQueue.main.async {
        completion(entities)
      }
    }
  }

  // FAST placement using pre-cloned entities (no main thread blocking!)
  private func placeGeolocationObjectsWithPreclonedEntities(arView: ARView, refLoc: CLLocationCoordinate2D, locations: [CLLocationCoordinate2D], entities: [ModelEntity?]) {
    let totalObjects = locations.count
    var placedCount = 0

    func placeNextObject(index: Int) {
      guard index < totalObjects else {
        if self.isDebugMode {
          print("✅ FAST_PLACEMENT: All \(placedCount) geolocation objects placed")
        }
        DispatchQueue.main.async {
          self.statusMessage = "Loot placed successfully!"
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.statusMessage = ""
          }
        }
        return
      }

      // This runs on main thread but is FAST (no cloning!)
      let location = locations[index]
      let arPositionInBaseFrame = self.convertToARWorldCoordinate(
        objectLocation: location, referenceLocation: refLoc)

      let objectAnchor = AnchorEntity()
      objectAnchor.position = arPositionInBaseFrame

      let pin = index < self.pinData.count ? self.pinData[index] : nil
      let markerNumber = (pin?.order ?? index) + 1
      let pinId = pin?.id ?? "unknown"
      let shortId = pinId.prefix(8)

      // Use pre-cloned entity (FAST - no blocking!)
      guard let entity = entities[index] else {
        if self.isDebugMode {
          print("⚠️ FAST_PLACEMENT: No entity at index \(index)")
        }
        placeNextObject(index: index + 1)
        return
      }

      objectAnchor.addChild(entity)
      self.entityToPinId[entity] = pinId
      self.baseOrientations[entity] = entity.transform.rotation
      self.coinEntities.append(entity)

      if self.isDebugMode {
        let numberLabel = self.createLabelEntity(text: "\(markerNumber)")
        numberLabel.position = [0, 0.25, 0]
        objectAnchor.addChild(numberLabel)

        let idLabel = self.createLabelEntity(text: String(shortId))
        idLabel.position = [0, 0.1, 0]
        objectAnchor.addChild(idLabel)
      }

      if let baseAnchor = self.baseAnchor {
        baseAnchor.addChild(objectAnchor)
      } else {
        arView.scene.addAnchor(objectAnchor)
      }

      self.anchors.append(objectAnchor)
      placedCount += 1

      self.statusMessage = "Placing loot... \(placedCount)/\(totalObjects)"
      if self.isDebugMode {
        print("⚡ FAST_PLACEMENT: Placed object \(placedCount)/\(totalObjects) - ID: \(shortId)")
      }

      // Place next immediately (no delay needed - it's fast!)
      placeNextObject(index: index + 1)
    }

    placeNextObject(index: 0)
  }

  private func placeProximityObjectsWithPreclonedEntities(arView: ARView, markers: [ProximityMarkerData], entities: [ModelEntity?]) {
    let totalObjects = markers.count
    var placedCount = 0

    func placeNextObject(index: Int) {
      guard index < totalObjects else {
        if self.isDebugMode {
          print("✅ FAST_PLACEMENT: All \(placedCount) proximity objects placed")
        }
        DispatchQueue.main.async {
          self.statusMessage = "Loot placed successfully!"
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.statusMessage = ""
          }
        }
        return
      }

      let marker = markers[index]
      guard let markerAngleRadians = self.parseDirectionStringToRadians(dir: marker.dir) else {
        placeNextObject(index: index + 1)
        return
      }

      let x_local = Float(marker.dist * sin(Double(markerAngleRadians)))
      let z_local = Float(-marker.dist * cos(Double(markerAngleRadians)))
      let objectHeight: Float = 0.0
      let arPositionInBaseFrame = SIMD3<Float>(x_local, objectHeight, z_local)

      let objectAnchor = AnchorEntity()
      objectAnchor.position = arPositionInBaseFrame

      let pin = index < self.pinData.count ? self.pinData[index] : nil
      let markerNumber = (pin?.order ?? index) + 1
      let pinId = pin?.id ?? "unknown"
      let shortId = pinId.prefix(8)

      guard let entity = entities[index] else {
        if self.isDebugMode {
          print("⚠️ FAST_PLACEMENT: No entity at index \(index)")
        }
        placeNextObject(index: index + 1)
        return
      }

      objectAnchor.addChild(entity)
      self.entityToPinId[entity] = pinId
      self.baseOrientations[entity] = entity.transform.rotation
      self.coinEntities.append(entity)

      if self.isDebugMode {
        let numberLabel = self.createLabelEntity(text: "\(markerNumber)")
        numberLabel.position = [0, 0.25, 0]
        objectAnchor.addChild(numberLabel)

        let idLabel = self.createLabelEntity(text: String(shortId))
        idLabel.position = [0, 0.1, 0]
        objectAnchor.addChild(idLabel)
      }

      if let baseAnchor = self.baseAnchor {
        baseAnchor.addChild(objectAnchor)
      } else {
        arView.scene.addAnchor(objectAnchor)
      }

      self.anchors.append(objectAnchor)
      placedCount += 1

      self.statusMessage = "Placing loot... \(placedCount)/\(totalObjects)"
      if self.isDebugMode {
        print("⚡ FAST_PLACEMENT: Placed object \(placedCount)/\(totalObjects) - ID: \(shortId)")
      }

      placeNextObject(index: index + 1)
    }

    placeNextObject(index: 0)
  }

  // Method to clear all previously placed anchors
  func clearAnchors() {
    print("Coordinator clearAnchors: Clearing \(anchors.count) previously placed anchors.")
    for anchor in self.anchors {
      anchor.removeFromParent()
    }
    self.anchors.removeAll()
    self.coinEntities.removeAll()
    self.baseOrientations.removeAll()

    // Clear horizon line but keep it for reuse
    horizonEntity?.removeFromParent()
    horizonEntity = nil

    print("Coordinator clearAnchors: All tracked anchors removed from scene and internal lists.")
  }
}
