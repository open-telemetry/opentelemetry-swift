/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class CounterMeterSdk<T: Numeric> : StableCounterMeter {
    let name : String
    let metricsLock = Lock()
    public private(set) var metrics = [AttributeSet : StableCounterMeasurementSdk<T>]()
    init(name: String) {
        self.name = name
    }

    func add(_ value: T, attributes: [String: AttributeValue]?) {
        var attributeSet = AttributeSet.empty
        if let attributes = attributes {
            attributeSet = AttributeSet(labels: attributes)
        }

        metricsLock.lock()
        defer {
            metricsLock.unlock()
        }

        if let metric = metrics[attributeSet] {
            metric.add(value: value)
        } else {
            metrics[attributeSet] = StableCounterMeasurementSdk<T>(value: value)
        }
    }
}

typealias IntCounterSdk = CounterMeterSdk<UInt>
typealias DoubleCounterSdk = CounterMeterSdk<Double>

