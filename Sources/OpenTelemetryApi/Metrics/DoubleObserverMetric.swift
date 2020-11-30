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

/// Observer instrument for Double values.
public protocol DoubleObserverMetric {
    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labelset: The labelset associated with this value.
    func observe(value: Double, labelset: LabelSet)

    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound counter metric.
    func observe(value: Double, labels: [String: String])
}

public struct NoopDoubleObserverMetric: DoubleObserverMetric {
    public init() {}

    public func observe(value: Double, labelset: LabelSet) {}

    public func observe(value: Double, labels: [String: String]) {}
}
