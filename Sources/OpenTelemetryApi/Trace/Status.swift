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

/// Defines the status of a Span by providing a standard CanonicalCode in conjunction
/// with an optional descriptive message. Instances of Status are created by starting with
///the template for the appropriate Status.CanonicalCode and supplementing it with
/// additional information
public struct Status: Equatable {
    /// The set of canonical status codes. If new codes are added over time they must choose a
    /// numerical value that does not collide with any previously used value.
    public enum CanonicalCode: Int {
        /// The operation completed successfully.
        case ok = 0
        /// The operation was cancelled (typically by the caller).
        case cancelled = 1
        /// Unknown error. An example of where this error may be returned is if a Status value received
        /// from another address space belongs to an error-space that is not known in this address space.
        /// Also errors raised by APIs that do not return enough error information may be converted to
        ///this error.
        case unknown = 2
        /// Client specified an invalid argument. Note that this differs from FAILED_PRECONDITION.
        /// INVALID_ARGUMENT indicates arguments that are problematic regardless of the state of the
        /// system  = e.g., a malformed file name).
        case invalid_argument = 3
        /// Deadline expired before operation could complete. For operations that change the state of the
        /// system, this error may be returned even if the operation has completed successfully. For
        /// example, a successful response from a server could have been delayed long enough for the
        /// deadline to expire.
        case deadline_exceeded = 4
        /// Some requested entity (e.g., file or directory) was not found.
        case not_found = 5
        /// Some entity that we attempted to create (e.g., file or directory) already exists.
        case already_exists = 6
        /// The caller does not have permission to execute the specified operation. PERMISSION_DENIED
        /// must not be used for rejections caused by exhausting some resource (use RESOURCE_EXHAUSTED
        /// instead for those errors). PERMISSION_DENIED must not be used if the caller cannot be
        /// identified (use UNAUTHENTICATED instead for those errors).
        case permission_denied = 7
        /// Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
        /// is out of space.
        case resource_exhausted = 8
        /// Operation was rejected because the system is not in a state required for the operation's
        /// execution. For example, directory to be deleted may be non-empty, an rmdir operation is
        /// applied to a non-directory, etc.
        /// A litmus test that may help a service implementor in deciding between FAILED_PRECONDITION,
        /// ABORTED, and UNAVAILABLE: (a) Use UNAVAILABLE if the client can retry just the failing call.
        /// (b) Use ABORTED if the client should retry at a higher-level (e.g., restarting a
        /// read-modify-write sequence). (c) Use FAILED_PRECONDITION if the client should not retry until
        ///the system state has been explicitly fixed. E.g., if an "rmdir" fails because the directory
        /// is non-empty, FAILED_PRECONDITION should be returned since the client should not retry unless
        ///they have first fixed up the directory by deleting files from it.
        case failed_precondition = 9
        /// The operation was aborted, typically due to a concurrency issue like sequencer check
        /// failures, transaction aborts, etc.
        /// See litmus test above for deciding between FAILED_PRECONDITION, ABORTED, and UNAVAILABLE.
        case aborted = 10
        /// Operation was attempted past the valid range. E.g., seeking or reading past end of file.
        /// Unlike INVALID_ARGUMENT, this error indicates a problem that may be fixed if the system
        /// state changes. For example, a 32-bit file system will generate INVALID_ARGUMENT if asked to
        /// read at an offset that is not in the range [0,2^32-1], but it will generate OUT_OF_RANGE if
        /// asked to read from an offset past the current file size.
        /// There is a fair bit of overlap between FAILED_PRECONDITION and OUT_OF_RANGE. We recommend
        /// using OUT_OF_RANGE (the more specific error) when it applies so that callers who are
        /// iterating through a space can easily look for an OUT_OF_RANGE error to detect when they are
        /// done.
        case out_of_range = 11
        /// Operation is not implemented or not supported/enabled in this service.
        case unimplemented = 12
        /// Internal errors. Means some invariants expected by underlying system has been broken. If you
        /// see one of these errors, something is very broken.
        case `internal` = 13
        /// The service is currently unavailable. This is a most likely a transient condition and may be
        /// corrected by retrying with a backoff.
        /// See litmus test above for deciding between FAILED_PRECONDITION, ABORTED, and UNAVAILABLE.
        case unavailable = 14
        /// Unrecoverable data loss or corruption.
        case data_loss = 15
        /// The request does not have valid authentication credentials for the operation.
        case unauthenticated = 16
        /// Returns the numerical value of the code.
        /// @return the numerical value of the code.
        /// @since 0.1.0
        public func value() -> Int {
            return rawValue
        }
    }

    // A pseudo-enum of Status instances mapped 1:1 with values in CanonicalCode. This simplifies
    // construction patterns for derived instances of Status.
    /// The operation completed successfully.
    public static let ok = Status(canonicalCode: CanonicalCode.ok)
    /// The operation was cancelled (typically by the caller).
    public static let cancelled = Status(canonicalCode: CanonicalCode.cancelled)
    /// Unknown error. See CanonicalCode.unknown.
    public static let unknown = Status(canonicalCode: CanonicalCode.unknown)
    /// Client specified an invalid argument. See CanonicalCode.invalid_argument.
    public static let invalid_argument = Status(canonicalCode: CanonicalCode.invalid_argument)
    /// Deadline expired before operation could complete. See CanonicalCode.deadline_exceeded.
    public static let deadline_exceeded = Status(canonicalCode: CanonicalCode.deadline_exceeded)
    /// Some requested entity (e.g., file or directory) was not found.
    public static let not_found = Status(canonicalCode: CanonicalCode.not_found)
    /// Some entity that we attempted to create (e.g., file or directory) already exists.
    public static let already_exists = Status(canonicalCode: CanonicalCode.already_exists)
    /// The caller does not have permission to execute the specified operation. See CanonicalCode.permission_denied
    public static let permission_denied = Status(canonicalCode: CanonicalCode.permission_denied)
    /// The request does not have valid authentication credentials for the operation.
    public static let unauthenticated = Status(canonicalCode: CanonicalCode.unauthenticated)
    /// Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
    /// is out of space.
    public static let resource_exhausted = Status(canonicalCode: CanonicalCode.resource_exhausted)
    /// Operation was rejected because the system is not in a state required for the operation's
    /// execution. See CanonicalCode.failed_precondition.
    public static let failed_precondition = Status(canonicalCode: CanonicalCode.failed_precondition)
    /// The operation was aborted, typically due to a concurrency issue like sequencer check failures,
    ///transaction aborts, etc. See CanonicalCode.aborted.
    public static let aborted = Status(canonicalCode: CanonicalCode.aborted)
    /// Operation was attempted past the valid range. See CanonicalCode.out_of_range.
    public static let out_of_range = Status(canonicalCode: CanonicalCode.out_of_range)
    /// Operation is not implemented or not supported/enabled in this service.
    public static let unimplemented = Status(canonicalCode: CanonicalCode.unimplemented)
    /// Internal errors. See CanonicalCode.internal.
    public static let `internal` = Status(canonicalCode: CanonicalCode.internal)
    /// The service is currently unavailable. See CanonicalCode.unavailable.
    public static let unavailable = Status(canonicalCode: CanonicalCode.unavailable)
    /// Unrecoverable data loss or corruption.
    public static let data_loss = Status(canonicalCode: CanonicalCode.data_loss)
    // The canonical code of this message.
    public private(set) var canonicalCode: CanonicalCode
    // An additional error message.
    public private(set) var statusDescription: String?

    private init(canonicalCode: CanonicalCode, description: String? = nil) {
        self.canonicalCode = canonicalCode
        statusDescription = description
    }

    /// Creates a derived instance of Status with the given description.
    /// - Parameter description: the new description of the Status
    public func withDescription(description: String?) -> Status {
        if statusDescription == description {
            return self
        }
        return Status(canonicalCode: canonicalCode, description: description)
    }

    /// True if this Status is OK, i.e., not an error.
    var isOk: Bool {
        return CanonicalCode.ok == canonicalCode
    }
}

extension Status: CustomStringConvertible {
    public var description: String {
        return "Status{canonicalCode=\(canonicalCode), description=\(statusDescription ?? "")"
    }
}
