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
