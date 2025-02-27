/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundRawCounterMetricSdkBase<T>: BoundRawCounterMetric<T> {
  var status: RecordStatus
  var statusLock = Lock()

  init(recordStatus: RecordStatus) {
    status = recordStatus
    super.init()
  }

  func checkpoint() {}

  func getMetrics() -> [MetricData] {
    fatalError()
  }
}
