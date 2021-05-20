/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class DoubleObserverMetricSdk: DoubleObserverMetric {
    public private(set) var observerHandles = [LabelSet: DoubleObserverMetricHandleSdk]()
    let metricName: String
    var callback: (DoubleObserverMetric) -> Void

    init(metricName: String, callback: @escaping (DoubleObserverMetric) -> Void) {
        self.metricName = metricName
        self.callback = callback
    }

    func observe(value: Double, labels: [String: String]) {
        observe(value: value, labelset: LabelSet(labels: labels))
    }

    func observe(value: Double, labelset: LabelSet) {
        var boundInstrument = observerHandles[labelset]
        if boundInstrument == nil {
            boundInstrument = DoubleObserverMetricHandleSdk()
            observerHandles[labelset] = boundInstrument
        }
        boundInstrument?.observe(value: value)
    }

    func invokeCallback() {
        callback(self)
    }
}
