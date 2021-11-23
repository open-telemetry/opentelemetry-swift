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

// this explicit Codable implementation for AttributeValue will probably be redundant with Swift 5.5
extension AttributeValue: Codable {
    enum CodingKeys: String, CodingKey {
        case string
        case bool
        case int
        case double
        case stringArray
        case boolArray
        case intArray
        case doubleArray
    }
         
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
            
        guard container.allKeys.count == 1 else {
            let context = DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid number of keys found, expected one.")
            throw DecodingError.typeMismatch(Status.self, context)
        }

        switch container.allKeys.first.unsafelyUnwrapped {
        case .string:
            self = .string(try container.decode(String.self, forKey: .string))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .bool))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .int))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .double))
        case .stringArray:
            self = .stringArray(try container.decode([String].self, forKey: .stringArray))
        case .boolArray:
            self = .boolArray(try container.decode([Bool].self, forKey: .boolArray))
        case .intArray:
            self = .intArray(try container.decode([Int].self, forKey: .intArray))
        case .doubleArray:
            self = .doubleArray(try container.decode([Double].self, forKey: .doubleArray))
        }
    }

    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .bool(let value):
            try container.encode(value, forKey: .bool)
        case .int(let value):
            try container.encode(value, forKey: .int)
        case .double(let value):
            try container.encode(value, forKey: .double)
        case .stringArray(let value):
            try container.encode(value, forKey: .stringArray)
        case .boolArray(let value):
            try container.encode(value, forKey: .boolArray)
        case .intArray(let value):
            try container.encode(value, forKey: .intArray)
        case .doubleArray(let value):
            try container.encode(value, forKey: .doubleArray)
        }
    }
}
