import ARKit
import CoreLocation
import Foundation
import RealityKit
import UIKit

extension ARViewContainer.Coordinator {
  // Helper to create model entity based on type
  // In debug mode, respects the debugObjectTypeOverride if set
  func createEntity(for type: ARObjectType) -> ModelEntity? {
    // Use debug override if set and in debug mode
    let effectiveType: ARObjectType
    if isDebugMode, let override = debugObjectTypeOverride, override != .none {
      effectiveType = override
    } else {
      effectiveType = type
    }

    switch effectiveType {
    case .coin:
      return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
    case .dollarSign:
      return CoinEntityFactory.makeCoin(style: CoinConfiguration.selectedStyle)
    case .giftCard:
      return GiftCardEntityFactory.makeGiftCard()
    case .none:
      return nil
    }
  }

  // More accurate GPS conversion function with debugging
  func convertToARWorldCoordinate(
    objectLocation: CLLocationCoordinate2D, referenceLocation: CLLocationCoordinate2D
  ) -> SIMD3<Float> {
    let referenceCLLocation = CLLocation(
      latitude: referenceLocation.latitude, longitude: referenceLocation.longitude)
    let objectCLLocation = CLLocation(
      latitude: objectLocation.latitude, longitude: objectLocation.longitude)
    let lat1 = referenceCLLocation.coordinate.latitude
    let lon1 = referenceCLLocation.coordinate.longitude
    let lat2 = objectCLLocation.coordinate.latitude
    let lon2 = objectCLLocation.coordinate.longitude

    // More accurate meters per degree calculation based on latitude
    let latitudeRadians = Self.degreesToRadians(lat1)
    let metersPerDegreeLat: Double =
      111132.92 - 559.82 * cos(2 * latitudeRadians) + 1.175 * cos(4 * latitudeRadians)
    let metersPerDegreeLon: Double =
      111412.84 * cos(latitudeRadians) - 93.5 * cos(3 * latitudeRadians)

    let deltaNorth: Double = (lat2 - lat1) * metersPerDegreeLat
    let deltaEast: Double = (lon2 - lon1) * metersPerDegreeLon

    // Calculate horizontal distance from reference point
    let horizontalDistance: Double = sqrt(deltaNorth * deltaNorth + deltaEast * deltaEast)

    // Adjusted to appear ~4 feet from user perspective
    let objectHeight: Float = 0.0

    if frameCounter % 300 == 0 {
      print("🗺️ GPS_CONVERSION: Dist: \(horizontalDistance)m, AR Pos: (\(deltaEast), \(objectHeight), \(-deltaNorth))")
    }

    return SIMD3<Float>(Float(deltaEast), objectHeight, Float(-deltaNorth))
  }

  // Helper to create a glowing, billboarded text label
  func createLabelEntity(text: String) -> ModelEntity {
    let textMesh = MeshResource.generateText(
      text,
      extrusionDepth: 0.01,
      font: .systemFont(ofSize: 0.3),
      containerFrame: .zero,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )

    let material = UnlitMaterial(color: UIColor.yellow)
    let labelEntity = ModelEntity(mesh: textMesh, materials: [material])
    labelEntity.name = "billboard_label"

    return labelEntity
  }

  func trackingStateDescription(_ state: ARCamera.TrackingState) -> String {
    switch state {
    case .normal:
      return "normal"
    case .notAvailable:
      return "notAvailable"
    case .limited(let reason):
      switch reason {
      case .excessiveMotion:
        return "limited: excessiveMotion"
      case .insufficientFeatures:
        return "limited: insufficientFeatures"
      case .initializing:
        return "limited: initializing"
      case .relocalizing:
        return "limited: relocalizing"
      @unknown default:
        return "limited: unknown"
      }
    }
  }

  // Helper function to parse direction string (e.g., "N32E") into radians
  func parseDirectionStringToRadians(dir: String) -> Float? {
    print("--- PARSER CALLED WITH: \(dir) ---")

    let pattern = #"^([NESW])(\d*)?([NESW])?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
      let match = regex.firstMatch(
        in: dir, options: [], range: NSRange(location: 0, length: dir.utf16.count))
    else {
      print("Failed to parse direction string format: \(dir)")
      return nil
    }

    var angleDegrees: Double = 0
    var baseAngle: Double = 0
    var deflectionAngle: Double = 0
    var deflectionDirection: Int = 1

    if match.numberOfRanges > 1, let range1 = Range(match.range(at: 1), in: dir) {
      let cardinal1 = String(dir[range1])
      switch cardinal1 {
      case "N": baseAngle = 0
      case "E": baseAngle = 90
      case "S": baseAngle = 180
      case "W": baseAngle = 270
      default: return nil
      }
    } else {
      return nil
    }

    if match.numberOfRanges > 2, let range2 = Range(match.range(at: 2), in: dir), !range2.isEmpty {
      if let degrees = Double(dir[range2]) {
        deflectionAngle = degrees
      } else {
        deflectionAngle = 0
      }
    } else {
      deflectionAngle = 0
    }

    if match.numberOfRanges > 3, let range3 = Range(match.range(at: 3), in: dir) {
      let cardinal2 = String(dir[range3])
      switch (dir.prefix(1), cardinal2) {
      case ("N", "E"), ("E", "S"), ("S", "W"), ("W", "N"):
        deflectionDirection = 1
      case ("N", "W"), ("E", "N"), ("S", "E"), ("W", "S"):
        deflectionDirection = -1
      default:
        if dir.count == 1 {
          deflectionAngle = 0
          deflectionDirection = 1
        } else {
          print("Failed to parse direction string format: \(dir) - Invalid cardinal combination")
          return nil
        }
      }
    } else {
      if dir.count == 1 {
        deflectionAngle = 0
        deflectionDirection = 1
      } else {
        print("Failed to parse direction string format: \(dir) - Missing second cardinal")
        return nil
      }
    }

    angleDegrees = baseAngle + (deflectionAngle * Double(deflectionDirection))
    angleDegrees = angleDegrees.truncatingRemainder(dividingBy: 360)
    if angleDegrees < 0 {
      angleDegrees += 360
    }

    print("Parsed direction string \(dir) to \(angleDegrees) degrees")
    return Float(angleDegrees * .pi / 180.0)
  }
}
