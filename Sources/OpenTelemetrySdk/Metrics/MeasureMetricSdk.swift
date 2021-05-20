/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

internal class MeasureMetricSdk<T: SignedNumeric & Comparable>: MeasureMetric {
    public private(set) var boundInstruments = [LabelSet: BoundMeasureMetricSdkBase<T>]()
    let metricName: String

    init(name: String) {
        metricName = name
    }

    func bind(labelset: LabelSet) -> BoundMeasureMetric<T> {
        var boundInstrument = boundInstruments[labelset]
        if boundInstrument == nil {
            boundInstrument = createMetric()
            boundInstruments[labelset] = boundInstrument!
        }
        return boundInstrument!
    }

    func bind(labels: [String: String]) -> BoundMeasureMetric<T> {
        return bind(labelset: LabelSet(labels: labels))
    }

    func createMetric() -> BoundMeasureMetricSdkBase<T> {
        return BoundMeasureMetricSdk<T>()
    }
}
