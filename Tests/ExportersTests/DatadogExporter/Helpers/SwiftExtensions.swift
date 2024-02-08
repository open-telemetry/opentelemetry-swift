/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest

/*
 Set of general extensions over standard types for writing more readable tests.
 Extensiosn using Datadog domain objects should be put in `DatadogExtensions.swift`.
 */

extension Optional {
    struct UnwrappingException: Error {}

    func unwrapOrThrow(file: StaticString = #file, line: UInt = #line) throws -> Wrapped {
        switch self {
        case .some(let unwrappedValue):
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

extension Calendar {
    static var gregorian: Calendar {
        return Calendar(identifier: .gregorian)
    }
}

extension String {
    var utf8Data: Data { data(using: .utf8)! }

    func removingPrefix(_ prefix: String) -> String {
        if self.hasPrefix(prefix) {
            return String(self.dropFirst(prefix.count))
        } else {
            fatalError("`\(self)` has no prefix of `\(prefix)`")
        }
    }
}

extension Data {
    var utf8String: String { String(decoding: self, as: UTF8.self) }
}

extension InputStream {
    func readAllBytes(expectedSize: Int) -> Data {
        var data = Data()

        open()

        let buffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: expectedSize)
        while hasBytesAvailable {
            let bytesRead = self.read(buffer, maxLength: expectedSize)

            guard bytesRead >= 0 else {
                fatalError("Stream error occurred.")
            }

            if bytesRead == 0 {
                break
            }

            data.append(buffer, count: bytesRead)
        }

        buffer.deallocate()
        close()

        return data
    }
}

extension URLRequest {
    func removing(httpHeaderField: String) -> URLRequest {
        var request = self
        request.setValue(nil, forHTTPHeaderField: httpHeaderField)
        return request
    }
}
