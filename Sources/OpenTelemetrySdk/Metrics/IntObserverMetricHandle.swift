/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class IntObserverMetricSdk: IntObserverMetric {
    public private(set) var observerHandles = [LabelSet: IntObserverMetricHandleSdk]()
    let metricName: String
    var callback: (IntObserverMetric) -> Void

    init(metricName: String, callback: @escaping (IntObserverMetric) -> Void) {
        self.metricName = metricName
        self.callback = callback
    }

    func observe(value: Int, labels: [String: String]) {
        observe(value: value, labelset: LabelSet(labels: labels))
    }

    func observe(value: Int, labelset: LabelSet) {
        var boundInstrument = observerHandles[labelset]
        if boundInstrument == nil {
            boundInstrument = IntObserverMetricHandleSdk()
            observerHandles[labelset] = boundInstrument
        }
        boundInstrument?.observe(value: value)
    }

    func invokeCallback() {
        callback(self)
    }
}
