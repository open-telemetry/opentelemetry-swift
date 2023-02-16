//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


typealias AggregationTemporalitySelector = (InstrumentType) -> AggregationTemporality

public enum AggregationTemporality {
    case delta
    case cumulative
    
    static func alwaysCumulative() -> AggregationTemporalitySelector {
        return  { (type: InstrumentType) -> AggregationTemporality in
            .cumulative
        }
        
    }
    
    static func deltaPreferred() -> AggregationTemporalitySelector {
        return { (type: InstrumentType) -> AggregationTemporality in
            switch(type) {
            case .upDownCounter, .observableUpDownCounter:
                return .cumulative
            case .counter, .observableCounter, .histogram, .observableGauge:
                return .delta
            }
        
        }
    }
}
