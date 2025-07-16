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
    withId huntId: String, completion: @escaping (Result<HuntData, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/hunts/\(huntId)"
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
    huntId: String, userId: String,
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

    let body = JoinHuntRequest(userId: userId)
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

      // Handle 409 status code specially for rejoining hunts
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
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    let body = CollectPinRequest(collectedByUserId: userId)
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
        let collectPinResponse = try JSONDecoder().decode(CollectPinResponse.self, from: data)
        completion(.success(collectPinResponse))
      } catch {
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

  public func updateUserName(
    userId: String, newName: String,
    completion: @escaping (Result<UserResponse, APIError>) -> Void
  ) {
    let urlString = "\(baseURL)/api/users/\(userId)"
    guard let url = URL(string: urlString) else {
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    let body: [String: String] = ["name": newName]
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
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
        let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
        completion(.success(userResponse))
      } catch {
        completion(.failure(.decodingError(error)))
      }
    }.resume()
  }
}
