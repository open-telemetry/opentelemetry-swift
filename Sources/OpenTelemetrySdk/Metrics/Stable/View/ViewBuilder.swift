//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


public class ViewBuilder {
    private var name : String?
    
    private var description : String?
    
    private var aggregation : Aggregation = Aggregations.defaultAggregation()
    
//    private var processor : AttributesProcessor = AttributesProcessor.noop()
    
    public func withName(name: String) -> Self {
        self.name = name
        return self
    }
    
    public func withDescription(description: String) -> Self {
        self.description = description
        return self
    }
    
    public func withAggregation(aggregation: Aggregation) -> Self {
        self.aggregation = aggregation
        return self
    }
    
//    public func addAttributeFilter( keyFilter: (String) -> Bool ) {
//        addAttributeProcessor(processor: AttributesProcessor.filterByKeyName(keyFilter))
//    }
    
//    public func addAttributeProcessor(processor: AttributesProcessor) -> Self {
//        self.processor = self.processor.then(processor: processor)
//        return self
//    }

    public func build() -> StableView {
        return StableView(name: name, description: description, aggregation: aggregation) //, attributesProcessor: processor)
    }
}


