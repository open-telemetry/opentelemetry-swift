//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class FilteredExemplarReservoir: AnyExemplarReservoir {
    let exemplarFilter : ExemplarFilter
    let reservoir : AnyExemplarReservoir
    
    init(filter: ExemplarFilter, reservoir: AnyExemplarReservoir) {
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
    
    public override func collectAndReset(attribute: [String : OpenTelemetryApi.AttributeValue]) -> [ExemplarData] {
        return reservoir.collectAndReset(attribute: attribute)
    }
}
