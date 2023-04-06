/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct StablePeriodicMetricReaderBuilder {
    var exporter : StableMetricExporter
    var exporterInterval : TimeInterval  = 1.0

    public init(exporter : StableMetricExporter) {
        self.exporter = exporter
    }
    
    mutating public func setInterval(timeInterval: TimeInterval) -> Self {
        self.exporterInterval = timeInterval
        return self
    }
    
    public func build() -> StablePeriodicMetricReaderSdk {
        return StablePeriodicMetricReaderSdk(exporter: exporter,
                exportInterval: exporterInterval)
    }
}
