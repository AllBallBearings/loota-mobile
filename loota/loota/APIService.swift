// APIService.swift

import CoreLocation
import Foundation

public class APIService {
  public static let shared = APIService()  // Singleton instance

  public enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unknownError

    public var errorDescription: String? {
      switch self {
      case .invalidURL:
        return "The API URL was invalid."
      case .networkError(let error):
        return "Network error: \(error.localizedDescription)"
      case .decodingError(let error):
        return "Failed to decode server response: \(error.localizedDescription)"
      case .serverError(let statusCode, let message):
        // Handle specific status codes with user-friendly messages
        switch statusCode {
        case 404:
          // Special handling for hunt not found errors
          if let message = message, message.contains("Hunt not found") {
            return "This treasure hunt link has expired or is no longer available. Please check with the hunt organizer for a new link."
          }
          return "The requested hunt could not be found. Please check your hunt link and try again."
        case 400:
          return "There was a problem with your request. Please try again."
        case 500...599:
          return "The treasure hunt server is temporarily unavailable. Please try again in a few minutes."
        default:
          return "Server error \(statusCode): \(message ?? "No message provided")"
        }
      case .unknownError:
        return "An unknown error occurred."
      }
    }
  }

  private let baseURL = Environment.current.baseURL
  private let session: URLSession

  private init() {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30  // 30 seconds
    configuration.timeoutIntervalForResource = 60  // 1 minute
    self.session = URLSession(configuration: configuration)
  }

  public func fetchHunt(
    withId huntId: String, userId: String? = nil, completion: @escaping (Result<HuntData, APIError>) -> Void
  ) {
    var urlString = "\(baseURL)/api/hunts/\(huntId)"
    if let userId = userId {
      urlString += "?userId=\(userId)"
    }
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      print("🌐 APIService - fetchHunt: Response data received, size: \(data.count) bytes")
      if let responseString = String(data: data, encoding: .utf8) {
        print("🌐 APIService - fetchHunt: Raw response: \(responseString)")
      }

      do {
        let decoder = JSONDecoder()
        let huntData = try decoder.decode(HuntData.self, from: data)
        print("🌐 APIService - fetchHunt: Successfully decoded HuntData")
        print("🌐 APIService - fetchHunt: Hunt ID: \(huntData.id)")
        print("🌐 APIService - fetchHunt: Hunt Name: '\(huntData.name ?? "nil")'")
        print("🌐 APIService - fetchHunt: Hunt Description: '\(huntData.description ?? "nil")'")
        print("🌐 APIService - fetchHunt: Hunt Type: \(huntData.type)")
        print("🌐 APIService - fetchHunt: Pins count: \(huntData.pins.count)")
        completion(.success(huntData))
      } catch {
        print("🌐 APIService - fetchHunt: ❌ DECODE ERROR: \(error)")
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func fetchHuntWithUserContext(
    huntId: String, userId: String, completion: @escaping (Result<HuntData, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/hunts/\(huntId)?userId=\(userId)"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let decoder = JSONDecoder()
        let huntData = try decoder.decode(HuntData.self, from: data)
        completion(.success(huntData))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func registerUser(
    name: String, phone: String?, payPalId: String?, deviceId: String,
    completion: @escaping (Result<UserRegistrationResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/users/register"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"  // Should be POST for registration
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    let body = UserRegistrationRequest(
      name: name, phone: phone, paypalId: payPalId, deviceId: deviceId)
    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      completion(.failure(.decodingError(error)))
      return
    }


    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let registrationResponse = try JSONDecoder().decode(
          UserRegistrationResponse.self, from: data)
        completion(.success(registrationResponse))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func joinHunt(
    huntId: String, userId: String, phoneNumber: String,
    completion: @escaping (Result<JoinHuntResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/hunts/\(huntId)/participants"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    let body = JoinHuntRequest(userId: userId, participantPhone: phoneNumber)
    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      completion(.failure(.decodingError(error)))
      return
    }


    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      // Handle special status codes
      if httpResponse.statusCode == 400 {
        if let data = data, let responseString = String(data: data, encoding: .utf8),
           responseString.contains("phone") || responseString.contains("Phone") {
          completion(.failure(.serverError(statusCode: 400, message: "Phone number is required to join hunts")))
          return
        }
      }
      
      if httpResponse.statusCode == 409 {
        if let data = data, let responseString = String(data: data, encoding: .utf8), responseString.contains("User is already participating in this hunt") {
            let syntheticResponse = JoinHuntResponse(message: "User is already participating in this hunt.", participationId: "", isRejoining: true)
            completion(.success(syntheticResponse))
            return
        }
      }
      
      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let joinHuntResponse = try JSONDecoder().decode(JoinHuntResponse.self, from: data)
        completion(.success(joinHuntResponse))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func collectPin(
    huntId: String, pinId: String, userId: String,
    completion: @escaping (Result<CollectPinResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/hunts/\(huntId)/pins/\(pinId)/collect"
    print("🌐 APIService - collectPin: Constructing URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
      print("🌐 APIService - collectPin: ❌ INVALID URL: \(urlString)")
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")
    
    print("🌐 APIService - collectPin: Request headers set")
    print("🌐   - Method: POST")
    print("🌐   - Content-Type: application/json") 
    print("🌐   - X-API-Key: \(Environment.current.apiKey.prefix(10))...")

    let body = CollectPinRequest(collectedByUserId: userId)
    print("🌐 APIService - collectPin: Request body created with userId: \(userId)")
    
    do {
      request.httpBody = try JSONEncoder().encode(body)
      if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
        print("🌐 APIService - collectPin: Request body JSON: \(bodyString)")
      }
    } catch {
      print("🌐 APIService - collectPin: ❌ FAILED to encode request body: \(error)")
      completion(.failure(.decodingError(error)))
      return
    }

    print("🌐 APIService - collectPin: Starting network request...")
    print("🌐 APIService - collectPin: Request timestamp: \(Date())")

    session.dataTask(with: request) { data, response, error in
      print("🌐 APIService - collectPin: Network request completed")
      print("🌐 APIService - collectPin: Response timestamp: \(Date())")
      
      if let error = error {
        print("🌐 APIService - collectPin: ❌ NETWORK ERROR: \(error)")
        print("🌐 APIService - collectPin: Error localizedDescription: \(error.localizedDescription)")
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        print("🌐 APIService - collectPin: ❌ NO HTTP RESPONSE")
        completion(.failure(.unknownError))
        return
      }

      print("🌐 APIService - collectPin: HTTP Status Code: \(httpResponse.statusCode)")
      print("🌐 APIService - collectPin: Response headers: \(httpResponse.allHeaderFields)")

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        print("🌐 APIService - collectPin: ❌ HTTP ERROR \(httpResponse.statusCode)")
        print("🌐 APIService - collectPin: Error response body: \(message ?? "nil")")
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        print("🌐 APIService - collectPin: ❌ NO RESPONSE DATA")
        completion(.failure(.unknownError))
        return
      }

      print("🌐 APIService - collectPin: Response data size: \(data.count) bytes")
      if let responseString = String(data: data, encoding: .utf8) {
        print("🌐 APIService - collectPin: Response body: \(responseString)")
      }

      do {
        let collectPinResponse = try JSONDecoder().decode(CollectPinResponse.self, from: data)
        print("🌐 APIService - collectPin: ✅ SUCCESS - Decoded response")
        print("🌐 APIService - collectPin: Response pinId: \(collectPinResponse.pinId)")
        print("🌐 APIService - collectPin: Response message: \(collectPinResponse.message)")
        completion(.success(collectPinResponse))
      } catch {
        print("🌐 APIService - collectPin: ❌ DECODE ERROR: \(error)")
        print("🌐 APIService - collectPin: Failed to decode response data")
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func getUser(
    userId: String,
    completion: @escaping (Result<UserResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/users/\(userId)"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")


    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
        completion(.success(userResponse))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func getUserByDeviceId(
    deviceId: String,
    completion: @escaping (Result<UserResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/users?deviceId=\(deviceId)"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let usersListResponse = try JSONDecoder().decode(UsersListResponse.self, from: data)
        if let user = usersListResponse.users.first {
          completion(.success(user))
        } else {
          // No user found with this device ID
          completion(.failure(.serverError(statusCode: 404, message: "User not found")))
        }
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }

  public func updateUser(
    deviceId: String, 
    name: String? = nil,
    phone: String? = nil,
    paypalId: String? = nil,
    completion: @escaping (Result<UserResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/users"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    let body = UserUpdateRequest(deviceId: deviceId, phone: phone, paypalId: paypalId, name: name)
    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      completion(.failure(.decodingError(error)))
      return
    }

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        completion(.failure(.unknownError))
        return
      }

      do {
        let updateResponse = try JSONDecoder().decode(UserUpdateResponse.self, from: data)
        completion(.success(updateResponse.user))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }
}
