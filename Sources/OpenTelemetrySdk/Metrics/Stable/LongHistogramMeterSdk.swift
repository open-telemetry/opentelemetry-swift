//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class LongHistogramMeterSdk : LongHistogram, Instrument {

    public var instrumentDescriptor: InstrumentDescriptor
    private var storage : WritableMetricStorage
    
    init(descriptor : InstrumentDescriptor, storage: WritableMetricStorage) {
        self.storage = storage
        self.instrumentDescriptor = descriptor
    }
    
    public func record(value: Int) {
        record(value: value, attributes: [String:AttributeValue]())
    }
    
    public func record(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        if value < 0 {
            print("Histograms can only record non-negative values. Instrument \(instrumentDescriptor.name) has recorded a negative value.")
            return
        }
        storage.recordLong(value: value, attributes: attributes)
    }
    
    
    
}
