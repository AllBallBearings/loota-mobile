// APIService.swift

import CoreLocation
import Foundation

public class APIService {
  public static let shared = APIService()  // Singleton instance
  private init() {}  // Private initializer to enforce singleton

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

  public func fetchHunt(
    withId huntId: String, completion: @escaping (Result<HuntData, APIError>) -> Void
  ) {
    let urlString = "https://www.loota.fun/api/hunts/\(huntId)"
    print("DEBUG: APIService - Attempting to fetch hunt with URL: \(urlString)")
    guard let url = URL(string: urlString) else {
      print("DEBUG: APIService - Invalid URL: \(urlString)")
      completion(.failure(.invalidURL))
      return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
      if let error = error {
        print("DEBUG: APIService - Network error: \(error.localizedDescription)")
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
}
