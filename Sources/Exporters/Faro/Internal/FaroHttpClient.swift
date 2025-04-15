/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Protocol for abstracting HTTP networking operations
protocol FaroHttpClient {
  /// Creates a data task that retrieves the contents of a URL based on the specified URL request and calls a handler upon completion
  /// - Parameters:
  ///   - request: A URL request object that provides the URL, cache policy, request type, etc.
  ///   - completionHandler: The completion handler to call when the request is complete
  /// - Returns: A new session data task
  func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> FaroHttpClientTask
}

protocol FaroHttpClientTask {
  func resume()
}

/// URLSession adapter conforming to FaroHttpClient
class URLSessionFaroHttpClient: FaroHttpClient {
  private let session: URLSession

  /// Initializes a new URLSessionFaroHttpClient instance
  /// - Parameter session: The URLSession to wrap, defaults to shared URLSession
  init(session: URLSession = .shared) {
    self.session = session
  }

  func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> FaroHttpClientTask {
    return session.dataTask(with: request, completionHandler: completionHandler)
  }
}

extension URLSessionDataTask: FaroHttpClientTask {}
