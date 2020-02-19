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

/// This class provides a mechanism for calculating the epoch time using Date().timeIntervalSince1970
/// and a reference epoch timestamp.
/// This clock needs to be re-created periodically in order to re-sync with the kernel clock, and
/// it is not recommended to use only one instance for a very long period of time.
public class MonotonicClock: Clock {
    let clock: Clock
    let epochNanos: Int
    let initialNanoTime: Int

    public init(clock: Clock) {
        self.clock = clock
        epochNanos = clock.now
        initialNanoTime = clock.nanoTime
    }

    public var now: Int {
        let deltaNanos = clock.nanoTime - initialNanoTime
        return epochNanos + deltaNanos
    }

    public var nanoTime: Int {
        return clock.nanoTime
    }
}
