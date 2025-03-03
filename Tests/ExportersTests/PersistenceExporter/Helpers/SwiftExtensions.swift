/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest

/*
 Set of general extensions over standard types for writing more readable tests.
 Extensiosn using Persistence domain objects should be put in `PersistenceExtensions.swift`.
 */

extension Optional {
  struct UnwrappingException: Error {}

  func unwrapOrThrow(file: StaticString = #file, line: UInt = #line) throws -> Wrapped {
    switch self {
    case let .some(unwrappedValue):
      return unwrappedValue
    case .none:
      XCTFail("Expected value, got `nil`.", file: file, line: line)
      throw UnwrappingException()
    }
  }
}

extension Date {
  func secondsAgo(_ seconds: TimeInterval) -> Date {
    return addingTimeInterval(-seconds)
  }
}

extension TimeZone {
  static var UTC: TimeZone { TimeZone(abbreviation: "UTC")! }
  static var EET: TimeZone { TimeZone(abbreviation: "EET")! }
  static func mockAny() -> TimeZone { .EET }
}

extension String {
  var utf8Data: Data { data(using: .utf8)! }
}

extension Data {
  var utf8String: String { String(decoding: self, as: UTF8.self) }
}
