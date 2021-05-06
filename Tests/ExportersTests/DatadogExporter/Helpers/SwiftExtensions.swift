// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import XCTest

/*
 Set of general extensions over standard types for writting more readable tests.
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
                fatalError("Stream error occured.")
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
