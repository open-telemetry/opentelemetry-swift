//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class FilteredExemplarReservoir<T : ExemplarData> : ExemplarReservoir<T> {
    let exemplarFilter : ExemplarFilter
    let reservoir : ExemplarReservoir<T>
    
    init(filter: ExemplarFilter, reservoir: ExemplarReservoir<T>) {
        self.exemplarFilter = filter
        self.reservoir = reservoir
    }
    
    public override func offerDoubleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        if exemplarFilter.shouldSampleMeasurement(value: value, attributes: attributes) {
            reservoir.offerDoubleMeasurement(value: value, attributes: attributes)
        }
    }
    
    public override func offerLongMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        if exemplarFilter.shouldSampleMeasurement(value: value, attributes: attributes) {
            reservoir.offerLongMeasurement(value: value, attributes: attributes)
        }
    }
    
    public override func collectAndReset(attribute: [String : OpenTelemetryApi.AttributeValue]) -> [T] {
        return reservoir.collectAndReset(attribute: attribute)
    }
}
