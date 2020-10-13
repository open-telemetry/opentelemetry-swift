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

internal protocol Delay {
    var current: TimeInterval { get }
    mutating func decrease()
    mutating func increase()
}

/// Mutable interval used for periodic data uploads.
internal struct DataUploadDelay: Delay {
    private let defaultDelay: TimeInterval
    private let minDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let changeRate: Double

    private var delay: TimeInterval

    init(performance: UploadPerformancePreset) {
        self.defaultDelay = performance.defaultUploadDelay
        self.minDelay = performance.minUploadDelay
        self.maxDelay = performance.maxUploadDelay
        self.changeRate = performance.uploadDelayChangeRate
        self.delay = performance.initialUploadDelay
    }

    var current: TimeInterval { delay }

    mutating func decrease() {
        delay = max(minDelay, delay * (1.0 - changeRate))
    }

    mutating func increase() {
        delay = min(delay * (1.0 + changeRate), maxDelay)
    }
}
