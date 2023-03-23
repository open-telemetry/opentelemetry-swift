//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct DoubleUpDownCounterSdk : DoubleUpDownCounter, Instrument {
    public private(set) var instrumentDescriptor: InstrumentDescriptor
    var storage : WritableMetricStorage
    
    init(instrumentDescriptor: InstrumentDescriptor, storage: inout WritableMetricStorage) {
        self.instrumentDescriptor = instrumentDescriptor
        self.storage = storage
    }
    
    mutating public func add(value: Double) {

        add(value: value, attributes: [String:AttributeValue]())
    }
    
    mutating public func add(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        storage.recordDouble(value: value, attributes: attributes)
    }
    
    
    
}
