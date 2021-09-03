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

protocol RandomMockable {
    static func mockRandom() -> Self
}

extension Data: AnyMockable, RandomMockable {
    static func mockAny() -> Data {
        return Data()
    }

    static func mockRepeating(byte: UInt8, times count: Int) -> Data {
        return Data(repeating: byte, count: count)
    }

    static func mock(ofSize size: UInt64) -> Data {
        return mockRepeating(byte: 0x41, times: Int(size))
    }

    static func mockRandom() -> Data {
        return mockRepeating(byte: .random(in: 0x00 ... 0xff), times: 256)
    }
}

extension Optional: AnyMockable where Wrapped: AnyMockable {
    static func mockAny() -> Self {
        return .some(.mockAny())
    }
}

extension Array where Element == Data {
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

extension Array {
    func randomElements() -> [Element] {
        return compactMap { Bool.random() ? $0 : nil }
    }
}

extension Array: RandomMockable where Element: RandomMockable {
    static func mockRandom() -> [Element] {
        return Array(repeating: .mockRandom(), count: 10)
    }
}

extension Dictionary: AnyMockable where Key: AnyMockable, Value: AnyMockable {
    static func mockAny() -> Dictionary {
        return [Key.mockAny(): Value.mockAny()]
    }
}

extension Dictionary: RandomMockable where Key: RandomMockable, Value: RandomMockable {
    static func mockRandom() -> Dictionary {
        return [Key.mockRandom(): Value.mockRandom()]
    }
}

extension Date: AnyMockable {
    static func mockAny() -> Date {
        return Date(timeIntervalSinceReferenceDate: 1)
    }

    static func mockSpecificUTCGregorianDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        dateComponents.timeZone = .UTC
        dateComponents.calendar = .gregorian
        return dateComponents.date!
    }

    static func mockDecember15th2019At10AMUTC(addingTimeInterval timeInterval: TimeInterval = 0) -> Date {
        return mockSpecificUTCGregorianDate(year: 2_019, month: 12, day: 15, hour: 10)
            .addingTimeInterval(timeInterval)
    }
}

extension URL: AnyMockable, RandomMockable {
    static func mockAny() -> URL {
        return URL(string: "https://www.datadoghq.com")!
    }

    static func mockWith(pathComponent: String) -> URL {
        return URL(string: "https://www.foo.com/")!.appendingPathComponent(pathComponent)
    }

    static func mockRandom() -> URL {
        return URL(string: "https://www.foo.com/")!
            .appendingPathComponent(
                .mockRandom(
                    among: .alphanumerics,
                    length: 32
                )
            )
    }

    static func mockRandomPath(containing subpathComponents: [String] = []) -> URL {
        let count: Int = .mockRandom(min: 2, max: 10)
        var components: [String] = (0..<count).map { _ in
            .mockRandom(
                among: .alphanumerics,
                length: .mockRandom(min: 3, max: 10)
            )
        }
        components.insert(contentsOf: subpathComponents, at: .random(in: 0..<count))
        return URL(fileURLWithPath: "/\(components.joined(separator: "/"))")
    }
}

extension String: AnyMockable, RandomMockable {
    static func mockAny() -> String {
        return "abc"
    }

    static func mockRandom() -> String {
        return mockRandom(length: 10)
    }

    static func mockRandom(length: Int) -> String {
        return mockRandom(
            among: .alphanumerics + " ",
            length: length
        )
    }

    static func mockRandom(among characters: String, length: Int = 10) -> String {
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    static func mockRepeating(character: Character, times: Int) -> String {
        let characters = (0..<times).map { _ in character }
        return String(characters)
    }

    static let alphanumerics = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    static let decimalDigits = "0123456789"
}

extension Int: AnyMockable, RandomMockable {
    static func mockAny() -> Int {
        return 0
    }

    static func mockRandom() -> Int {
        return mockRandom(min: .min, max: .max)
    }

    static func mockRandom(min: Int, max: Int) -> Int {
        return .random(in: min ... max)
    }
}

extension Bool {
    static func mockAny() -> Bool {
        return false
    }
}

extension TimeInterval {
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

struct FailingEncodableMock: Encodable {
    let errorMessage: String

    func encode(to encoder: Encoder) throws {
        throw ErrorMock(errorMessage)
    }
}

// MARK: - HTTP

extension HTTPURLResponse {
    static func mockResponseWith(statusCode: Int) -> HTTPURLResponse {
        return HTTPURLResponse(url: .mockAny(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}

extension URLRequest {
    static func mockAny() -> URLRequest {
        return URLRequest(url: .mockAny())
    }
}
