/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class TestMetricExporter: MetricExporter {
  var metrics = [Metric]()
  let onExport: () -> Void

  init(onExport: @escaping () -> Void) {
    self.onExport = onExport
  }

  func export(metrics: [Metric], shouldCancel: (() -> Bool)? = nil) -> MetricExporterResultCode {
    onExport()
    self.metrics.append(contentsOf: metrics)
    return .success
  }
}
