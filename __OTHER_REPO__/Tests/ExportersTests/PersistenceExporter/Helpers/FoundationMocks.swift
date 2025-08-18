/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/*
 A collection of mocks for different `Foundation` types. The convention we use is to extend
 types with static factory function prefixed with "mock". For example:

 ```
 extension URL {
    static func mockAny() -> URL {
        // ...
    }
 }

 extension URLSession {
    static func mockDeliverySuccess(data: Data, response: HTTPURLResponse) -> URLSessionMock {
        // ...
    }
 }
 ```

 Other conventions to follow:
 * Use the name `mockAny()` to name functions that return any value of given type.
 * Use descriptive function and parameter names for functions that configure the object for particular scenario.
 * Always use the minimal set of parameters which is required by given mock scenario.

 */

// MARK: - Basic types

protocol AnyMockable {
  static func mockAny() -> Self
}

extension Data: AnyMockable {
  static func mockAny() -> Data {
    return Data()
  }

  static func mockRepeating(byte: UInt8, times count: Int) -> Data {
    return Data(repeating: byte, count: count)
  }

  static func mock(ofSize size: UInt64) -> Data {
    return mockRepeating(byte: 0x41, times: Int(size))
  }
}

extension [Data] {
  /// Returns chunks of mocked data. Accumulative size of all chunks equals `totalSize`.
  static func mockChunksOf(totalSize: UInt64, maxChunkSize: UInt64) -> [Data] {
    var chunks: [Data] = []
    var bytesWritten: UInt64 = 0

    while bytesWritten < totalSize {
      let bytesLeft = totalSize - bytesWritten
      var nextChunkSize: UInt64 = bytesLeft > Int.max ? UInt64(Int.max) : bytesLeft // prevents `Int` overflow
      nextChunkSize = nextChunkSize > maxChunkSize ? maxChunkSize : nextChunkSize // caps the next chunk to its max size
      chunks.append(.mockRepeating(byte: 0x1, times: Int(nextChunkSize)))
      bytesWritten += UInt64(nextChunkSize)
    }

    return chunks
  }
}

extension Date: AnyMockable {
  static func mockAny() -> Date {
    return Date(timeIntervalSinceReferenceDate: 1)
  }
}

extension TimeInterval: AnyMockable {
  static func mockAny() -> TimeInterval {
    return 0
  }

  static let distantFuture = TimeInterval(integerLiteral: .max)
}

struct ErrorMock: Error, CustomStringConvertible {
  let description: String

  init(_ description: String = "") {
    self.description = description
  }
}

struct FailingCodableMock: Codable {
  init() {}

  init(from decoder: Decoder) throws {
    throw ErrorMock("Failing codable failed to decode")
  }

  func encode(to encoder: Encoder) throws {
    throw ErrorMock("Failing codable failed to encode")
  }
}
