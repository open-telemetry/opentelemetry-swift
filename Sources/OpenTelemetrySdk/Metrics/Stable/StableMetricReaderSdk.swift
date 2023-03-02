/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
class StableMetricReaderSdk : StableMetricReader {
    let exporter : StableMetricExporter
    let sharedState : StableMeterSharedState
    let exportInterval : TimeInterval
    let exportTimeout : TimeInterval

    func forceFlush() -> Bool {
        do {
            try sharedState.meterRegistry.forEach { meter in
             _ = try meter.collect()
            }
        } catch {
            return false
        }
        return true
    }

    init(exporter: StableMetricExporter, sharedState: StableMeterSharedState, exportInterval: TimeInterval = 60.0, exportTimeout: TimeInterval = 30.0) {
        self.sharedState = sharedState
        self.exporter = exporter
        self.exportInterval = exportInterval
        self.exportTimeout = exportTimeout
    }

    func collect() -> Bool {
        fatalError("collect() has not been implemented")
    }

    func shutdown() -> Bool {
        fatalError("shutdown() has not been implemented")
    }
    
    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
        exporter.getAggregationTemporality(for: instrument)
    }
    
    func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
        return exporter.getDefaultAggregation(for: instrument)
    }
    
}


