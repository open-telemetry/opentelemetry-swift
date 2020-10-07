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

// MARK: - TimeInterval

extension TimeInterval {
    /// `TimeInterval` represented in milliseconds (capped to `UInt64.max`).
    var toMilliseconds: UInt64 {
        let miliseconds = self * 1_000
        return (try? UInt64(withReportingOverflow: miliseconds)) ?? .max
    }

    /// `TimeInterval` represented in nanoseconds (capped to `UInt64.max`).
    /// Note: as `TimeInterval` yields sub-millisecond precision the nanoseconds precission will be lost.
    var toNanoseconds: UInt64 {
        let nanoseconds = self * 1_000_000_000
        return (try? UInt64(withReportingOverflow: nanoseconds)) ?? .max
    }
}

// MARK: - Safe floating point to integer conversion

internal enum FixedWidthIntegerError<T: BinaryFloatingPoint>: Error {
    case overflow(overflowingValue: T)
}

extension FixedWidthInteger {
    /* NOTE: RUMM-182
     Self(:) is commonly used for conversion, however it fatalError() in case of conversion failure
     Self(exactly:) does the exact same thing internally yet it returns nil instead of fatalError()
     It is not trivial to guess if the conversion would fail or succeed, therefore we use Self(exactly:)
     so that we don't need to guess in order to save the app from crashing

     IMPORTANT: If you pass floatingPoint to Self(exactly:) without rounded(), it may return nil
     */
    init<T: BinaryFloatingPoint>(withReportingOverflow floatingPoint: T) throws {
        guard let converted = Self(exactly: floatingPoint.rounded()) else {
            throw FixedWidthIntegerError<T>.overflow(overflowingValue: floatingPoint)
        }
        self = converted
    }
}
