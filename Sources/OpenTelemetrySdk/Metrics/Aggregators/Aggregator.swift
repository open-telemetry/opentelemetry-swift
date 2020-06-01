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

protocol Aggregator: AnyObject {
    associatedtype T
    func update(value: T)
    func checkpoint()
    func toMetricData() -> MetricData
    func getAggregationType() -> AggregationType
}

public class AnyAggregator<T>: Aggregator {
    private let _update: (T) -> Void
    private let _checkpoint: () -> Void
    private let _toMetricData: () -> MetricData
    private let _getAggregationType: () -> AggregationType

    init<U: Aggregator>(_ aggregable: U) where U.T == T {
        _update = aggregable.update
        _checkpoint = aggregable.checkpoint
        _toMetricData = aggregable.toMetricData
        _getAggregationType = aggregable.getAggregationType
    }

    func update(value: T) {
        _update(value)
    }

    func checkpoint() {
        _checkpoint()
    }

    func toMetricData() -> MetricData {
        return _toMetricData()
    }

    func getAggregationType() -> AggregationType {
        return _getAggregationType()
    }
}
