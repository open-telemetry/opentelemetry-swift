//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


public typealias AggregationResolver = (InstrumentType) -> Aggregation




public class AggregationSelector {
    
    public let selector : AggregationResolver
    
    init(selector: @escaping AggregationResolver = AggregationSelector.defaultSelector())  {
        self.selector = selector
    }
    
    static func defaultSelector() -> AggregationResolver {
        return { instrumentType in
            return Aggregation.defaultAggregation()
        }
    }
    func with(instrumentType : InstrumentType, aggregation : Aggregation) -> AggregationResolver {
        return { instrumentType1 in
            if instrumentType == instrumentType1 {
                return aggregation
            }
            return self.selector(instrumentType1)
        }
    }
}
