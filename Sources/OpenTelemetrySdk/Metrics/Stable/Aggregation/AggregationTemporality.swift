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
    
    public init(aggregationTemporalitySelector: @escaping (InstrumentType) -> AggregationTemporality) {
        self.aggregationTemporalitySelector = aggregationTemporalitySelector
    }
    
    public var aggregationTemporalitySelector: (InstrumentType) -> AggregationTemporality
}

public enum AggregationTemporality {
    case delta
    case cumulative
    
    public static func alwaysCumulative() -> AggregationTemporalitySelector {
        return  AggregationTemporalitySelector() { (type) in
            .cumulative
        }
        
    }
  
    public static func alwaysDelta() -> AggregationTemporalitySelector {
        return AggregationTemporalitySelector() { (type) in
            .delta
        }
    }
    
    public static func deltaPreferred() -> AggregationTemporalitySelector {
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
