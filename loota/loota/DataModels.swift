// DataModels.swift

import CoreLocation
import Foundation

// MARK: - API and Hunt Data Models

public enum HuntType: String, Codable {
  case geolocation
  case proximity
}

public struct PinData: Codable {
  public let id: String?  // Added missing field
  public let huntId: String?  // Added missing field
  public let lat: Double?
  public let lng: Double?
  public let distanceFt: Double?
  public let directionStr: String?
  public let x: Double?
  public let y: Double?
  public let createdAt: String?  // Added missing field

  // Custom initializer to handle String to Double conversion for lat and lng
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    huntId = try container.decodeIfPresent(String.self, forKey: .huntId)

    // Decode lat and lng as String, then convert to Double
    if let latString = try container.decodeIfPresent(String.self, forKey: .lat) {
      lat = Double(latString)
    } else {
      lat = nil
    }

    if let lngString = try container.decodeIfPresent(String.self, forKey: .lng) {
      lng = Double(lngString)
    } else {
      lng = nil
    }

    distanceFt = try container.decodeIfPresent(Double.self, forKey: .distanceFt)
    directionStr = try container.decodeIfPresent(String.self, forKey: .directionStr)
    x = try container.decodeIfPresent(Double.self, forKey: .x)
    y = try container.decodeIfPresent(Double.self, forKey: .y)
    createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
  }

  // Manual encoding if needed, or rely on default if only decoding is custom
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(huntId, forKey: .huntId)
    try container.encodeIfPresent(lat?.description, forKey: .lat)  // Encode as String
    try container.encodeIfPresent(lng?.description, forKey: .lng)  // Encode as String
    try container.encodeIfPresent(distanceFt, forKey: .distanceFt)
    try container.encodeIfPresent(directionStr, forKey: .directionStr)
    try container.encodeIfPresent(x, forKey: .x)
    try container.encodeIfPresent(y, forKey: .y)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
  }

  // Define CodingKeys for all properties
  private enum CodingKeys: String, CodingKey {
    case id, huntId, lat, lng, distanceFt, directionStr, x, y, createdAt
  }
}

public struct HuntData: Codable {
  public let id: String
  public let type: HuntType
  public let winnerId: String?  // Added missing field
  public let createdAt: String?  // Added missing field
  public let updatedAt: String?  // Added missing field
  public let pins: [PinData]
}

// MARK: - AR and View-Related Data Models

public enum ARObjectType: String, CaseIterable, Identifiable {
  case none = "None"
  case coin = "Coin"
  case dollarSign = "Dollar Sign"
  public var id: String { self.rawValue }
}

public struct ProximityMarkerData: Identifiable {
  public let id: UUID
  public let dist: Double  // Distance in meters
  public let dir: String  // Direction string, e.g., "N32E"

  public init(dist: Double, dir: String) {
    self.id = UUID()
    self.dist = dist
    self.dir = dir
  }
}
