//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol MetricStorage  {
    var metricDescriptor : MetricDescriptor { get }
    func collect(resource : Resource, scope : InstrumentationScopeInfo, startEpochNanos: Int, epochNanos : Int) -> StableMetricData
    func isEmpty() -> Bool
}


public protocol WritableMetricStorage {
    func recordLong(value: Int, attributes: [String: AttributeValue])
    func recordDouble(value: Double, attributes: [String: AttributeValue])
}


