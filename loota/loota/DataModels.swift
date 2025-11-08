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
  public let objectType: ARObjectType?  // Loot type (coin, giftCard, dollarSign)

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
    objectType = try container.decodeIfPresent(ARObjectType.self, forKey: .objectType)
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
    try container.encodeIfPresent(objectType, forKey: .objectType)
  }

  // Define CodingKeys for all properties
  private enum CodingKeys: String, CodingKey {
    case id, huntId, lat, lng, distanceFt, directionStr, x, y, order, createdAt, collectedByUserId, collectedAt, objectType
  }
}

public struct HuntData: Codable {
  public let id: String
  public let name: String?
  public let description: String?
  public let type: HuntType
  public let winnerId: String?
  public let createdAt: String?
  public let updatedAt: String?
  public let creatorId: String?
  public var pins: [PinData]
  public let isCompleted: Bool?
  public let completedAt: String?
  public let participants: [ParticipantData]
  public let creator: UserInfo?
  public let winner: UserInfo?
  public let winnerContact: WinnerContact?
  public let creatorContact: CreatorContact?
}

public struct ParticipantData: Codable {
  public let id: String
  public let userId: String
  public let huntId: String
  public let joinedAt: String
  public let participantPhone: String?
  public let user: UserInfo
}

public struct UserInfo: Codable {
  public let id: String
  public let name: String
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
  public let phone: String?
  public let paypalId: String?
  public let deviceId: String?
  public let createdAt: String?
  
  private enum CodingKeys: String, CodingKey {
    case userId = "id"
    case name
    case phone
    case paypalId
    case deviceId
    case createdAt
  }
}

public struct UsersListResponse: Codable {
  public let users: [UserResponse]
}

public struct UserUpdateRequest: Codable {
  let deviceId: String
  let phone: String?
  let paypalId: String?
  let name: String?
}

public struct UserUpdateResponse: Codable {
  public let user: UserResponse
}

public struct JoinHuntRequest: Codable {
  let userId: String
  let participantPhone: String
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

// MARK: - Hunt Completion and Contact Models

public struct WinnerContact: Codable {
  public let name: String?
  public let phone: String?
}

public struct CreatorContact: Codable {
  public let name: String?
  public let preferred: String?
  public let phone: String?
  public let email: String?
}

// MARK: - Error Handling

public enum HuntError: Error, LocalizedError {
  case phoneNumberRequired
  case huntNotFound
  case alreadyParticipating
  case huntCompleted
  case networkError
  case invalidPhoneNumber
  
  public var errorDescription: String? {
    switch self {
    case .phoneNumberRequired:
      return "Phone number is required to join hunts for prize contact"
    case .huntNotFound:
      return "Hunt not found"
    case .alreadyParticipating:
      return "You're already participating in this hunt"
    case .huntCompleted:
      return "This hunt has already been completed"
    case .networkError:
      return "Network error occurred"
    case .invalidPhoneNumber:
      return "Please enter a valid phone number"
    }
  }
}

// MARK: - AR and View-Related Data Models

public enum ARObjectType: String, CaseIterable, Identifiable {
  case none = "None"
  case coin = "Coin"
  case dollarSign = "Dollar Sign"
  case giftCard = "Gift Card"
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
