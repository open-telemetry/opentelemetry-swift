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
  private let logger: FaroLogging
  private let timeout: TimeInterval = 30.0

  // MARK: - Initialization

  /// Initializes a new FaroTransport instance
  /// - Parameters:
  ///   - endpointConfiguration: Configuration for connecting to the Faro backend
  ///   - sessionManager: Manager for Faro sessions
  ///   - httpClient: Client for making HTTP requests, defaults to URLSessionFaroHttpClient
  ///   - logger: Logger for transport operations, defaults to FaroLogger
  init(endpointConfiguration: FaroEndpointConfiguration,
       sessionManager: FaroSessionManaging,
       httpClient: FaroHttpClient = URLSessionFaroHttpClient(),
       logger: FaroLogging = FaroLoggingFactory.getInstance()) {
    self.endpointConfiguration = endpointConfiguration
    self.sessionManager = sessionManager
    self.httpClient = httpClient
    self.logger = logger
  }

  // MARK: - Public Methods

  func send(_ payload: FaroPayload, completion: @escaping (Result<Void, Error>) -> Void) {
    var request = URLRequest(url: endpointConfiguration.collectorUrl)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Add API key
    request.addValue(endpointConfiguration.apiKey, forHTTPHeaderField: "x-api-key")

    // Add session ID
    let sessionId = sessionManager.getSession().id
    request.addValue(sessionId, forHTTPHeaderField: "x-faro-session-id")

    // Set timeout
    request.timeoutInterval = timeout

    // Set the payload
    do {
      request.httpBody = try JSONEncoder().encode(payload)
    } catch {
      logger.logError("FaroTransport: Failed to encode payload", error: error)
      completion(.failure(FaroTransportError.encodingError(error)))
      return
    }

    // Send the request
    let task = httpClient.dataTask(with: request) { data, response, error in
      // Handle network error
      if let error {
        self.logger.logError("FaroTransport:Network error", error: error)
        completion(.failure(FaroTransportError.networkError(error)))
        return
      }

      // Check HTTP status code
      if let httpResponse = response as? HTTPURLResponse {
        let statusCode = httpResponse.statusCode
        if statusCode < 200 || statusCode >= 300 {
          let responseData = data != nil ? String(data: data!, encoding: .utf8) : nil
          self.logger.logError("FaroTransport: HTTP error: status=\(statusCode), response=\(responseData ?? "nil")", error: nil)
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
