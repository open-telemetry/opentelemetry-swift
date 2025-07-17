/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

@available(*, deprecated, renamed: "PeriodicMetricReaderBuilder")
public typealias StablePeriodicMetricReaderBuilder = PeriodicMetricReaderBuilder

public class PeriodicMetricReaderBuilder {
  public private(set) var exporter: MetricExporter
  public private(set) var exporterInterval: TimeInterval = 1.0

  public init(exporter: MetricExporter) {
    self.exporter = exporter
  }

  public func setInterval(timeInterval: TimeInterval) -> Self {
    exporterInterval = timeInterval
    return self
  }

  public func build() -> PeriodicMetricReaderSdk {
    return PeriodicMetricReaderSdk(exporter: exporter,
                                         exportInterval: exporterInterval)
  }
}
