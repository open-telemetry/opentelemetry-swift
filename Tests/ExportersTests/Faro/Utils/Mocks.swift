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
  let attributes: [String: String] = [:]

  func getSession() -> FaroSession {
    return FaroSession(id: sessionId, attributes: attributes)
  }

  func updateLastActivity(date: Date) {}

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

  func iso8601String(from date: Date) -> String {
    return iso8601Formatter.string(from: date)
  }

  /// Advances the mock's current date by the specified time interval
  /// - Parameter timeInterval: The amount of time to advance by
  func advance(by timeInterval: TimeInterval) {
    internalCurrentDate = internalCurrentDate.addingTimeInterval(timeInterval)
  }

  func date(fromISO8601String string: String) -> Date? {
    iso8601Formatter.date(from: string)
  }
}

final class MockDeviceAttributesProvider: FaroDeviceAttributesProviding {
  let mockAttributes = [
    "device_manufacturer": "apple",
    "device_os": "iOS",
    "device_os_version": "16.0",
    "device_model": "iPhone14,3",
    "device_id": "mock-device-id"
  ]

  func getDeviceAttributes() -> [String: String] {
    return mockAttributes
  }
}

class MockFaroTransport: FaroTransportable {
  var sentPayloads: [FaroPayload] = []
  var sendResult: Result<Void, Error> = .success(())
  var sendExpectation: XCTestExpectation?

  func send(_ payload: FaroPayload, completion: @escaping (Result<Void, Error>) -> Void) {
    sentPayloads.append(payload)
    sendExpectation?.fulfill()
    completion(sendResult)
  }

  func failNextSend(with error: Error = NSError(domain: "MockError", code: 1, userInfo: nil)) {
    sendResult = .failure(error)
  }
}

/// Silent implementation of FaroLogging for tests
class MockFaroLogger: FaroLogging {
  var loggedMessages: [String] = []
  var loggedErrors: [(message: String, error: Error?)] = []

  func log(_ message: String) {
    loggedMessages.append(message)
  }

  func logError(_ message: String, error: Error?) {
    loggedErrors.append((message: message, error: error))
  }

  func reset() {
    loggedMessages = []
    loggedErrors = []
  }
}

final class MockDeviceInformationSource: DeviceInformationSource {
    var osName: String
    var osVersion: String
    var deviceBrand: String
    var deviceModel: String
    var isPhysical: Bool
    
    init(
        osName: String,
        osVersion: String,
        deviceBrand: String,
        deviceModel: String,
        isPhysical: Bool
    ) {
        self.osName = osName
        self.osVersion = osVersion
        self.deviceBrand = deviceBrand
        self.deviceModel = deviceModel
        self.isPhysical = isPhysical
    }
}

final class MockPersistentDeviceIdentifierProvider: PersistentDeviceIdentifierProviding {
    var mockIdentifier: String
    
    init(mockIdentifier: String) {
        self.mockIdentifier = mockIdentifier
    }
    
    func getIdentifier() -> String {
        return mockIdentifier
    }
}

class MockUserDefaults: UserDefaultsProviding {
    private var storage: [String: Any] = [:]
    
    func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
}