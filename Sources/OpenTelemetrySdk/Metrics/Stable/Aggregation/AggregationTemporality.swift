//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public protocol AggregationTemporalitySelectorProtocol {
    func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality
}

public class AggregationTemporalitySelector : AggregationTemporalitySelectorProtocol {
    public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
        return aggregationTemporalitySelector(instrument)
    }
    
    init(aggregationTemporalitySelector: @escaping (InstrumentType) -> AggregationTemporality) {
        self.aggregationTemporalitySelector = aggregationTemporalitySelector
    }
    
    public var aggregationTemporalitySelector: (InstrumentType) -> AggregationTemporality
}

public enum AggregationTemporality {
    case delta
    case cumulative
    
    static func alwaysCumulative() -> AggregationTemporalitySelector {
        return  AggregationTemporalitySelector() { (type) in
            .cumulative
        }
        
    }
    
    static func deltaPreferred() -> AggregationTemporalitySelector {
        return  AggregationTemporalitySelector() { type in
            switch(type) {
            case .upDownCounter, .observableUpDownCounter:
                return .cumulative
            case .counter, .observableCounter, .histogram, .observableGauge:
                return .delta
            }
        
        }
    }
}
