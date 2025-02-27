/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class TestMetricProcessor: MetricProcessor {
  var metrics = [Metric]()
  func finishCollectionCycle() -> [Metric] {
    let metrics = self.metrics
    self.metrics = [Metric]()
    return metrics
  }

  func process(metric: Metric) {
    metrics.append(metric)
  }
}
