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
        return "Server error \(statusCode): \(message ?? "No message provided")"
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
    print("DEBUG: APIService - Attempting to fetch hunt with URL: \(urlString)")
    guard let url = URL(string: urlString) else {
      print("DEBUG: APIService - Invalid URL: \(urlString)")
      completion(.failure(.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"  // Assuming GET for fetchHunt
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(Environment.current.apiKey, forHTTPHeaderField: "X-API-Key")

    // Log request headers for debugging
    print("DEBUG: APIService - Fetch Hunt Request Headers: \(request.allHTTPHeaderFields ?? [:])")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        print(
          "DEBUG: APIService - Network error for \(url.absoluteString): \(error.localizedDescription). Full error: \(error)"
        )
        completion(.failure(.networkError(error)))
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        print("DEBUG: APIService - Unknown response type.")
        completion(.failure(.unknownError))
        return
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        print(
          "DEBUG: APIService - Server error: Status Code \(httpResponse.statusCode), Message: \(message ?? "N/A")"
        )
        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
        return
      }

      guard let data = data else {
        print("DEBUG: APIService - No data received from server.")
        completion(.failure(.unknownError))
        return
      }

      print(
        "DEBUG: APIService - Raw data received (length: \(data.count)): \(String(data: data, encoding: .utf8) ?? "Could not decode to UTF8")"
      )

      do {
        let decoder = JSONDecoder()
        let huntData = try decoder.decode(HuntData.self, from: data)
        print("DEBUG: APIService - Successfully decoded hunt data: \(huntData)")
        completion(.success(huntData))
      } catch {
        print(
          "DEBUG: APIService - Decoding error: \(error.localizedDescription), Data: \(String(data: data, encoding: .utf8) ?? "N/A")"
        )
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

    // Log request headers for debugging
    print(
      "DEBUG: APIService - Register User Request Headers: \(request.allHTTPHeaderFields ?? [:])")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        print(
          "DEBUG: APIService - Network error for \(request.url?.absoluteString ?? "N/A"): \(error.localizedDescription). Full error: \(error)"
        )
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

    // Log request headers for debugging
    print("DEBUG: APIService - Join Hunt Request Headers: \(request.allHTTPHeaderFields ?? [:])")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        print(
          "DEBUG: APIService - Network error for \(request.url?.absoluteString ?? "N/A"): \(error.localizedDescription). Full error: \(error)"
        )
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
            // If the user is already in the hunt, treat it as a success/rejoin scenario.
            // Create a synthetic response since the error response body is not a JoinHuntResponse.
            print("DEBUG: APIService - Handled 409 as a successful rejoin.")
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

    // Log request headers for debugging
    print("DEBUG: APIService - Collect Pin Request Headers: \(request.allHTTPHeaderFields ?? [:])")

    session.dataTask(with: request) { data, response, error in
      if let error = error {
        print(
          "DEBUG: APIService - Network error for \(request.url?.absoluteString ?? "N/A"): \(error.localizedDescription). Full error: \(error)"
        )
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
}
