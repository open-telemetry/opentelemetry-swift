// Copyright 2021, OpenTelemetry Authors
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


class IntObservableGaugeSdk : IntObserverMetric {
    public private(set) var observerHandles = [LabelSet: IntObservableGaugeHandle]()
    let name : String
    var callback : (IntObserverMetric) -> Void

    init(measurementName: String, callback: @escaping (IntObserverMetric)->Void) {
        self.name = measurementName
        self.callback = callback
    }

    func observe(value: Int, labels: [String: String]) {
        observe(value: value, labelset: LabelSet(labels: labels))
    }

    func observe(value: Int, labelset: LabelSet) {
        var boundInstrument = observerHandles[labelset]
        if boundInstrument == nil {
            boundInstrument = IntObservableGaugeHandle()
            observerHandles[labelset] = boundInstrument
        }
        boundInstrument?.observe(value: value)
    }

    func invokeCallback() {
        callback(self)
    }
}
