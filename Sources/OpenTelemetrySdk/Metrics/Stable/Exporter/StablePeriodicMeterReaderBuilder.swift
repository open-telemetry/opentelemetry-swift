/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class StablePeriodicMetricReaderBuilder {
    public private(set) var exporter : StableMetricExporter
    public private(set) var exporterInterval : TimeInterval  = 1.0

    public init(exporter : StableMetricExporter) {
        self.exporter = exporter
    }
    
    public func setInterval(timeInterval: TimeInterval) -> Self {
        self.exporterInterval = timeInterval
        return self
    }
    
    public func build() -> StablePeriodicMetricReaderSdk {
        return StablePeriodicMetricReaderSdk(exporter: exporter,
                exportInterval: exporterInterval)
    }
}
