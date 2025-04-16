/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
@testable import FaroExporter

/// Mock HTTP client for testing network interactions
class MockFaroHttpClient: FaroHttpClient {
  var lastRequest: URLRequest?
  var mockResponse: (data: Data?, response: URLResponse?, error: Error?)?

  func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> FaroHttpClientTask {
    lastRequest = request

    if let mockResponse {
      completionHandler(mockResponse.data, mockResponse.response, mockResponse.error)
    } else {
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
      completionHandler(nil, response, nil)
    }

    return MockURLSessionDataTask()
  }
}

/// Mock task for testing HTTP client interactions
class MockURLSessionDataTask: FaroHttpClientTask {
  func resume() {}
}

/// Mock session manager for testing session handling
class MockFaroSessionManager: FaroSessionManaging {
  let sessionId = "mock-session-id"

  func getSessionId() -> String {
    return sessionId
  }

  /// Callback that will be called when the session ID changes
  var onSessionIdChanged: ((String, String) -> Void)?
}

/// A mock implementation of DateProviding for testing purposes
final class MockDateProvider: DateProviding {
  private var internalCurrentDate: Date
  private let iso8601Formatter: ISO8601DateFormatter

  init(initialDate: Date = Date()) {
    internalCurrentDate = initialDate

    iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0)
  }

  func currentDate() -> Date {
    return internalCurrentDate
  }

  func currentDateISO8601String() -> String {
    return iso8601Formatter.string(from: currentDate())
  }

  func iso8601String(from date: Date) -> String {
    return iso8601Formatter.string(from: date)
  }

  /// Advances the mock's current date by the specified time interval
  /// - Parameter timeInterval: The amount of time to advance by
  func advance(by timeInterval: TimeInterval) {
    internalCurrentDate = internalCurrentDate.addingTimeInterval(timeInterval)
  }
}
