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

class CounterMetricSdk<T: SignedNumeric>: CounterMetricSdkBase<T> {
    override init(name: String) {
        super.init(name: name)
    }

    override func add(value: T, labelset: LabelSet) {
        bind(labelset: labelset, isShortLived: true).add(value: value)
    }

    override func add(value: T, labels: [String: String]) {
        bind(labelset: LabelSetSdk(labels: labels), isShortLived: true).add(value: value)
    }

    override func createMetric(recordStatus: RecordStatus) -> BoundCounterMetricSdkBase<T> {
        return BoundCounterMetricSdk<T>(recordStatus: recordStatus)
    }
}
