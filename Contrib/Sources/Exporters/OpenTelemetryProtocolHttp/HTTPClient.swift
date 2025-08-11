//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Protocol for sending HTTP requests, allowing custom implementations for authentication and other behaviors.
public protocol HTTPClient {
  /// Sends an HTTP request and calls the completion handler with the result.
  /// - Parameters:
  ///   - request: The URLRequest to send
  ///   - completion: Completion handler called with Result<HTTPURLResponse, Error>
  func send(request: URLRequest,
            completion: @escaping (Result<HTTPURLResponse, Error>) -> Void)
}

/// Default implementation of HTTPClient using URLSession.
public final class BaseHTTPClient: HTTPClient {
  private let session: URLSession

  /// Creates a BaseHTTPClient with default ephemeral session configuration.
  public convenience init() {
    let configuration: URLSessionConfiguration = .ephemeral
    // NOTE: RUMM-610 Default behaviour of `.ephemeral` session is to cache requests.
    // To not leak requests memory (including their `.httpBody` which may be significant)
    // we explicitly opt-out from using cache. This cannot be achieved using `.requestCachePolicy`.
    configuration.urlCache = nil
    // TODO: RUMM-123 Optimize `URLSessionConfiguration` for good traffic performance
    // and move session configuration constants to `PerformancePreset`.
    self.init(session: URLSession(configuration: configuration))
  }

  /// Creates a BaseHTTPClient with a custom URLSession.
  /// - Parameter session: The URLSession to use for HTTP requests
  public init(session: URLSession) {
    self.session = session
  }

  public func send(request: URLRequest,
                   completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
    let task = session.dataTask(with: request) { data, response, error in
      completion(httpClientResult(for: (data, response, error)))
    }
    task.resume()
  }
}

/// An error returned if `URLSession` response state is inconsistent (like no data, no response and no error).
struct HTTPClientError: Error, CustomStringConvertible {
  let description: String
}

/// Maps `URLSessionDataTask` response to `HTTPClient` response.
func httpClientResult(for taskResult: (Data?, URLResponse?, Error?)) -> Result<HTTPURLResponse, Error> {
  let (_, response, error) = taskResult

  if let error = error {
    return .failure(error)
  }

  guard let httpResponse = response as? HTTPURLResponse else {
    return .failure(
      HTTPClientError(
        description: "Failed to receive HTTPURLResponse: \(String(describing: response))"
      )
    )
  }

  return .success(httpResponse)
}