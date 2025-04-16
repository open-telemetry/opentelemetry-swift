/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Protocol defining the transport layer interface for sending telemetry data to Faro backend.
/// Implementers of this protocol are responsible for handling the network communication
/// and delivery of telemetry payloads to the appropriate endpoints.
protocol FaroTransportable {
  /// Sends the provided payload to the Faro backend
  /// - Parameters:
  ///   - payload: The telemetry payload to be delivered
  ///   - completion: A completion handler called when the send operation completes with a success or failure result
  func send(_ payload: FaroPayload, completion: @escaping (Result<Void, Error>) -> Void)
}

/// FaroTransport is responsible for handling the transport layer of telemetry data to Faro backend.
/// This class manages the sending of telemetry data including logs, traces, and metrics.
final class FaroTransport: FaroTransportable {
  // MARK: - Properties

  private let endpointConfiguration: FaroEndpointConfiguration
  private let sessionManager: FaroSessionManaging
  private let httpClient: FaroHttpClient
  private let timeout: TimeInterval = 30.0

  // MARK: - Initialization

  /// Initializes a new FaroTransport instance
  /// - Parameters:
  ///   - endpointConfiguration: Configuration for connecting to the Faro backend
  ///   - sessionManager: Manager for Faro sessions
  ///   - httpClient: Client for making HTTP requests, defaults to URLSessionFaroHttpClient
  init(endpointConfiguration: FaroEndpointConfiguration,
       sessionManager: FaroSessionManaging,
       httpClient: FaroHttpClient = URLSessionFaroHttpClient()) {
    self.endpointConfiguration = endpointConfiguration
    self.sessionManager = sessionManager
    self.httpClient = httpClient
  }

  // MARK: - Public Methods

  func send(_ payload: FaroPayload, completion: @escaping (Result<Void, Error>) -> Void) {
    var request = URLRequest(url: endpointConfiguration.collectorUrl)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Add API key
    request.addValue(endpointConfiguration.apiKey, forHTTPHeaderField: "x-api-key")

    // Add session ID
    let sessionId = sessionManager.getSessionId()
    request.addValue(sessionId, forHTTPHeaderField: "x-faro-session-id")

    // Set timeout
    request.timeoutInterval = timeout

    // Set the payload
    do {
      // Debug: Print the payload
      let jsonEncoder = JSONEncoder()
      jsonEncoder.outputFormatting = [.prettyPrinted]
      let jsonData = try jsonEncoder.encode(payload)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("### === FaroPayload JSON ===")
        print(jsonString)
        print("### ========================")
      }
      // Debug: END

      request.httpBody = try JSONEncoder().encode(payload)
    } catch {
      print("FaroTransport: Failed to encode payload: \(error)")
      completion(.failure(FaroTransportError.encodingError(error)))
      return
    }

    // Send the request
    let task = httpClient.dataTask(with: request) { data, response, error in
      // Handle network error
      if let error {
        print("FaroTransport: Network error: \(error)")
        completion(.failure(FaroTransportError.networkError(error)))
        return
      }

      // Check HTTP status code
      if let httpResponse = response as? HTTPURLResponse {
        let statusCode = httpResponse.statusCode
        if statusCode < 200 || statusCode >= 300 {
          let responseData = data != nil ? String(data: data!, encoding: .utf8) : nil
          print("FaroTransport: HTTP error: status=\(statusCode), response=\(responseData ?? "nil")")
          completion(.failure(FaroTransportError.httpError(statusCode, responseData)))
          return
        }
      }

      // Success
      completion(.success(()))
    }

    task.resume()
  }
}

/// Errors that can occur during Faro transport operations
enum FaroTransportError: Error {
  case encodingError(Error)
  case networkError(Error)
  case httpError(Int, String?)
}
