//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol MetricProducer: CollectionRegistration {
  func collectAllMetrics() -> [MetricData]
}

public struct NoopMetricProducer: MetricProducer {
  public func collectAllMetrics() -> [MetricData] {
    return [MetricData]()
  }
}
