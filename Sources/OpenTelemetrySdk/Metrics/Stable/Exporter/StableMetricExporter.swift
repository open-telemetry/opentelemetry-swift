//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
public protocol StableMetricExporter : AggregationTemporalitySelectorProtocol, DefaultAggregationSelector {

    func export(metrics : [StableMetricData]) -> ExportResult
    func flush() -> ExportResult
    func shutdown() -> ExportResult
}

extension StableMetricExporter {
    public func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
        return Aggregations.defaultAggregation()
    }
}
