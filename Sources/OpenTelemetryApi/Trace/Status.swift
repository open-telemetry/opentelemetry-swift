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

/// The set of canonical status codes. If new codes are added over time they must choose a numerical
/// value that does not collide with any previously used value.
public struct Status: Equatable {
    /// The set of canonical status codes. If new codes are added over time they must choose a
    /// numerical value that does not collide with any previously used value.
    public enum StatusCode: Int {
        /// The operation has been validated by an Application developers or Operator to have completed successfully.
        case ok = 0
        /// The default status.
        case unset = 1
        /// The operation contains an error.
        case error = 2
    }

    // A pseudo-enum of Status instances mapped 1:1 with values in StatusCode. This simplifies
    // construction patterns for derived instances of Status.

    /// The default status.
    public static let unset = Status(statusCode: StatusCode.unset)
    /// The operation has been validated by an Application developers or Operator to have completed successfully.
    public static let ok = Status(statusCode: StatusCode.ok)
    /// The operation contains an error.
    public static let error = Status(statusCode: StatusCode.error)


    public private(set) var statusCode: StatusCode
    // An additional error message.
    public private(set) var statusDescription: String?

    private init(statusCode: StatusCode, description: String? = nil) {
        self.statusCode = statusCode
        statusDescription = description
    }

    /// Creates a derived instance of Status with the given description.
    /// - Parameter description: the new description of the Status
    public func withDescription(description: String?) -> Status {
        if statusDescription == description {
            return self
        }
        return Status(statusCode: statusCode, description: description)
    }

    /// True if this Status is OK
    public var isOk: Bool {
        return StatusCode.ok == statusCode
    }

    /// True if this Status is an Error
    public var isError: Bool {
        return StatusCode.error == statusCode
    }
}

extension Status: CustomStringConvertible {
    public var description: String {
        return "Status{statusCode=\(statusCode), description=\(statusDescription ?? "")"
    }
}
