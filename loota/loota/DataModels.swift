// DataModels.swift

import CoreLocation
import Foundation

// MARK: - API and Hunt Data Models

public enum HuntType: String, Codable {
  case geolocation
  case proximity
}

public struct PinData: Codable {
  public let id: String?
  public let huntId: String?
  public let lat: Double?
  public let lng: Double?
  public let distanceFt: Double?
  public let directionStr: String?
  public let x: Double?
  public let y: Double?
  public let order: Int?
  public let createdAt: String?
  public let collectedByUserId: String?
  public let collectedAt: String?

  // Custom initializer to handle flexible lat/lng decoding (String or Double)
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    huntId = try container.decodeIfPresent(String.self, forKey: .huntId)

    // Decode lat and lng - try Double first, then String as fallback
    if let latDouble = try container.decodeIfPresent(Double.self, forKey: .lat) {
      lat = latDouble
    } else if let latString = try container.decodeIfPresent(String.self, forKey: .lat) {
      lat = Double(latString)
    } else {
      lat = nil
    }

    if let lngDouble = try container.decodeIfPresent(Double.self, forKey: .lng) {
      lng = lngDouble
    } else if let lngString = try container.decodeIfPresent(String.self, forKey: .lng) {
      lng = Double(lngString)
    } else {
      lng = nil
    }

    distanceFt = try container.decodeIfPresent(Double.self, forKey: .distanceFt)
    directionStr = try container.decodeIfPresent(String.self, forKey: .directionStr)
    x = try container.decodeIfPresent(Double.self, forKey: .x)
    y = try container.decodeIfPresent(Double.self, forKey: .y)
    order = try container.decodeIfPresent(Int.self, forKey: .order)
    createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    collectedByUserId = try container.decodeIfPresent(String.self, forKey: .collectedByUserId)
    collectedAt = try container.decodeIfPresent(String.self, forKey: .collectedAt)
  }

  // Manual encoding if needed, or rely on default if only decoding is custom
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(huntId, forKey: .huntId)
    try container.encodeIfPresent(lat, forKey: .lat)  // Encode as Double
    try container.encodeIfPresent(lng, forKey: .lng)  // Encode as Double
    try container.encodeIfPresent(distanceFt, forKey: .distanceFt)
    try container.encodeIfPresent(directionStr, forKey: .directionStr)
    try container.encodeIfPresent(x, forKey: .x)
    try container.encodeIfPresent(y, forKey: .y)
    try container.encodeIfPresent(order, forKey: .order)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(collectedByUserId, forKey: .collectedByUserId)
    try container.encodeIfPresent(collectedAt, forKey: .collectedAt)
  }

  // Define CodingKeys for all properties
  private enum CodingKeys: String, CodingKey {
    case id, huntId, lat, lng, distanceFt, directionStr, x, y, order, createdAt, collectedByUserId, collectedAt
  }
}

public struct HuntData: Codable {
  public let id: String
  public let type: HuntType
  public let winnerId: String?
  public let createdAt: String?
  public let updatedAt: String?
  public let creatorId: String?
  public var pins: [PinData]
}

// MARK: - User and Hunt Interaction Models

public struct UserRegistrationRequest: Codable {
  let name: String
  let phone: String?
  let paypalId: String?
  let deviceId: String
}

public struct UserRegistrationResponse: Codable {
  let message: String
  let userId: String
}

public struct UserResponse: Codable {
  public let userId: String
  public let name: String
  
  private enum CodingKeys: String, CodingKey {
    case userId = "id"
    case name
  }
}

public struct JoinHuntRequest: Codable {
  let userId: String
}

public struct JoinHuntResponse: Codable {
  let message: String
  let participationId: String
  let isRejoining: Bool
}

public struct CollectPinRequest: Codable {
  let collectedByUserId: String
}

public struct CollectPinResponse: Codable {
  let message: String
  let pinId: String
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
