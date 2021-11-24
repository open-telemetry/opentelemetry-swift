/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// The set of canonical status codes. If new codes are added over time they must choose a numerical
/// value that does not collide with any previously used value.
public enum Status: Equatable {
    /// The operation has been validated by an Application developers or Operator to have completed successfully.
    case ok
    /// The default status.
    case unset
    /// The operation contains an error.
    case error(description: String)

    /// True if this Status is OK
    public var isOk: Bool {
        return self == .ok
    }

    /// True if this Status is an Error
    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    public var name: String {
        switch self {
            case .ok:
                return "ok"
            case .unset:
                return "unset"
            case .error(description: _):
                return "error"
        }
    }

    public var code: Int {
        switch self {
            case .ok:
                return 0
            case .unset:
                return 1
            case .error(description: _):
                return 2
        }
    }
}

extension Status: CustomStringConvertible {
    public var description: String {
        if case let Status.error(description) = self {
            return "Status{statusCode=\(name), description=\(description)}"
        } else {
            return "Status{statusCode=\(name)}"
        }
    }
}

internal struct StatusExplicitCodable : Codable {
    let status: Status
    
    enum CodingKeys: String, CodingKey {
        case ok
        case unset
        case error
    }

    enum EmptyCodingKeys: CodingKey {

    }

    enum ErrorCodingKeys: String, CodingKey {
        case description
    }

    internal init(status: Status) {
        self.status = status
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
        case .ok:
            _ = try container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .ok)
            self.status = .ok
        case .unset:
            _ = try container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .unset)
            self.status = .unset
        case .error:
            let nestedContainer = try container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
            self.status = .error(description: try nestedContainer.decode(String.self, forKey: .description))
        }
    }

    public func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self.status {
        case .ok:
            _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .ok)
        case .unset:
            _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .unset)
        case .error(let description):
            var nestedContainer = container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
            try nestedContainer.encode(description, forKey: .description)
        }
    }
}

#if swift(>=5.5)
// swift 5.5 supports synthesizing Codable for enums with associated values
// see https://github.com/apple/swift-evolution/blob/main/proposals/0295-codable-synthesis-for-enums-with-associated-values.md
extension Status: Codable { }
#else
// for older swift versions use a forward compatible explicit Codable implementation
extension Status: Codable {

    public init(from decoder: Decoder) throws {
        let explicitDecoded = try StatusExplicitCodable(from: decoder)
        
        self = explicitDecoded.status
    }

    public func encode(to encoder: Encoder) throws {
        let explicitEncoded = StatusExplicitCodable(status: self)
        
        try explicitEncoded.encode(to: encoder)
    }        
}
#endif
