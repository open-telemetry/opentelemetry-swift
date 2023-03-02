//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class EmptyMetricStorage : SynchronousMetricStorage {
    public func recordLong(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
    }
    
    public func recordDouble(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
    }
    
    public static var instance = EmptyMetricStorage()
    
    public var metricDescriptor: MetricDescriptor = MetricDescriptor(name: "", description: "", unit: "")
    
    public func collect(resource: Resource, scope: InstrumentationScopeInfo, startEpochNanos: Int, epochNanos: Int) -> StableMetricData {
        StableMetricData.empty
    }
    
    public func isEmpty() -> Bool {
        true
    }
    
    
    
}
