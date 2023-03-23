//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct LongUpDownCounterSdk : LongUpDownCounter, Instrument {
    public private(set) var instrumentDescriptor: InstrumentDescriptor
    var storage : WritableMetricStorage
    
    init(instrumentDescriptor: InstrumentDescriptor, storage: inout WritableMetricStorage){
        self.instrumentDescriptor = instrumentDescriptor
        self.storage = storage
    }
    

    mutating public func add(value: Int) {
        add(value: value, attributes: [String: AttributeValue]())
    }
    
    mutating public func add(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        storage.recordLong(value: value, attributes: attributes)

    }
    
    
    
}
