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

internal class BoundMeasureMetricSdk<T: SignedNumeric & Comparable>: BoundMeasureMetricSdkBase<T> {
    private var measureAggregator = MeasureMinMaxSumCountAggregator<T>()
    
    override init() {
        super.init()
    }

    override func record(inContext: SpanContext, value: T) {
        measureAggregator.update(value: value)
    }

//    override func record(inContext: DistributedContext, value: T) {
//        measureAggregator.update(value: value)
//    }

    override func getAggregator() -> AnyAggregator<T> {
        return AnyAggregator<T>(measureAggregator)
    }
}
