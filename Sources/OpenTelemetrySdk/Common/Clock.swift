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
import OpenTelemetryApi

/// Interface for getting the current time.
public protocol Clock: AnyObject {
    /// Obtains the current epoch timestamp in nanos from this clock.
    var now: Int { get }

    /// Returns a time measurement with nanosecond precision that can only be used to calculate elapsed
    /// time.
    var nanoTime: Int { get }
}

public func == (lhs: Clock, rhs: Clock) -> Bool {
    return lhs.now == rhs.now && lhs.nanoTime == rhs.nanoTime
}
