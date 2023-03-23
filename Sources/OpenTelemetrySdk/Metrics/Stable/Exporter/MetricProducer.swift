//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public protocol MetricProducer : CollectionRegistration  {
    func collectAllMetrics() -> [StableMetricData]
}


public struct NoopMetricProducer  : MetricProducer {
    
    
    public func collectAllMetrics() -> [StableMetricData] {
        return [StableMetricData]()
    }
}
