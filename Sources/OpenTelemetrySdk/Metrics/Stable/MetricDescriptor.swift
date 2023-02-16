//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public struct MetricDescriptor {
    public private(set) var name : String
    public private(set) var description : String
    public private(set) var view : StableView
    public private(set) var instrument : InstrumentDescriptor
    
    
    init(name: String, description: String, unit: String) {
        self.init(view: StableView.builder().build(), InstrumentDescriptor(name: name, description: description, unit: unit, type: .observableGauge, valueType: .double))
    }
    
    init(view: StableView, instrument: InstrumentDescriptor) {
        if let name = view.name {
            self.name = name
        } else {
            self.name = instrument.name
        }
        
        if let description = view.description {
            self.description = description
        } else {
            self.description = instrument.description
        }
        self.view = view
        self.instrument = instrument
    }
    
    public func aggregationName() -> String {
        return String(describing: view.aggregation)
    }
}
