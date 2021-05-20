/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An enum that represents all the possible values for an attribute.
public enum AttributeValue: Equatable, CustomStringConvertible, Hashable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case stringArray([String])
    case boolArray([Bool])
    case intArray([Int])
    case doubleArray([Double])

    public var description: String {
        switch self {
        case let .string(value):
            return value
        case let .bool(value):
            return value ? "true" : "false"
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        case let .stringArray(value):
            return value.description
        case let .boolArray(value):
            return value.description
        case let .intArray(value):
            return value.description
        case let .doubleArray(value):
            return value.description
        }
    }

    public init?(_ value: Any) {
        switch value {
        case let val as String:
            self = .string(val)
        case let val as Bool:
            self = .bool(val)
        case let val as Int:
            self = .int(val)
        case let val as Double:
            self = .double(val)
        case let val as [String]:
            self = .stringArray(val)
        case let val as [Bool]:
            self = .boolArray(val)
        case let val as [Int]:
            self = .intArray(val)
        case let val as [Double]:
            self = .doubleArray(val)
        default:
            return nil
        }
    }
}

extension AttributeValue: Encodable {
    enum CodingKeys: String, CodingKey {
        case description
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
    }
}
