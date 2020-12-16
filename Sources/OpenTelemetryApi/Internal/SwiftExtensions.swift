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

public extension TimeInterval {
    /// `TimeInterval` represented in milliseconds (capped to `UInt64.max`).
    var toMilliseconds: UInt64 {
        let miliseconds = self * 1_000
        return UInt64(withReportingOverflow: miliseconds) ?? .max
    }

    /// `TimeInterval` represented in nanoseconds (capped to `UInt64.max`).
    var toNanoseconds: UInt64 {
        let nanoseconds = self * 1_000_000_000
        return UInt64(withReportingOverflow: nanoseconds) ?? .max
    }

    static func fromNanoseconds(_ nanos: UInt64) -> TimeInterval {
        return Double(nanos) / 1000000000
    }
}

fileprivate extension FixedWidthInteger {
      init?<T: BinaryFloatingPoint>(withReportingOverflow floatingPoint: T) {
        guard let converted = Self(exactly: floatingPoint.rounded()) else {
            return nil
        }
        self = converted
    }
}
