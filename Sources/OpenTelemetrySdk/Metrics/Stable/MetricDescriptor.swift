//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation


public struct MetricDescriptor: Hashable {
    public private(set) var name: String
    public private(set) var description: String
    public private(set) var view: StableView
    public private(set) var instrument: InstrumentDescriptor
        
    init(name: String, description: String, unit: String) {
        self.init(view: StableView.builder().build(), instrument: InstrumentDescriptor(name: name, description: description, unit: unit, type: .observableGauge, valueType: .double))
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
    
    public static func == (lhs: MetricDescriptor, rhs: MetricDescriptor) -> Bool {
        return lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.aggregationName() == rhs.aggregationName() &&
            lhs.instrument.name == rhs.instrument.name &&
            lhs.instrument.description == rhs.instrument.description &&
            lhs.instrument.unit == rhs.instrument.unit &&
            lhs.instrument.type == rhs.instrument.type &&
            lhs.instrument.valueType == rhs.instrument.valueType
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(aggregationName())
        hasher.combine(instrument.name)
        hasher.combine(instrument.description)
        hasher.combine(instrument.unit)
        hasher.combine(instrument.type)
        hasher.combine(instrument.valueType)
    }
}
