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
    case .error:
      return "error"
    }
  }

  public var code: Int {
    switch self {
    case .ok:
      return 0
    case .unset:
      return 1
    case .error:
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

struct StatusExplicitCodable: Codable {
  let status: Status

  enum CodingKeys: String, CodingKey {
    case ok
    case unset
    case error
  }

  enum EmptyCodingKeys: CodingKey {}

  enum ErrorCodingKeys: String, CodingKey {
    case description
  }

  init(status: Status) {
    self.status = status
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.allKeys.count == 1 else {
      let context = DecodingError.Context(codingPath: container.codingPath,
                                          debugDescription: "Invalid number of keys found, expected one.")
      throw DecodingError.typeMismatch(Status.self, context)
    }

    switch container.allKeys.first.unsafelyUnwrapped {
    case .ok:
      _ = try container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .ok)
      status = .ok
    case .unset:
      _ = try container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .unset)
      status = .unset
    case .error:
      let nestedContainer = try container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
      status = try .error(
        description: nestedContainer.decode(String.self, forKey: .description))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch status {
    case .ok:
      _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .ok)
    case .unset:
      _ = container.nestedContainer(keyedBy: EmptyCodingKeys.self, forKey: .unset)
    case let .error(description):
      var nestedContainer = container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .error)
      try nestedContainer.encode(description, forKey: .description)
    }
  }
}

extension Status: Codable {}
