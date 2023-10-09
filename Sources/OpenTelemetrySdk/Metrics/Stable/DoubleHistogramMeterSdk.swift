//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleHistogramMeterSdk: DoubleHistogram, Instrument {
    public var instrumentDescriptor: InstrumentDescriptor
    public var storage: WritableMetricStorage

    init(instrumentDescriptor: InstrumentDescriptor, storage: WritableMetricStorage) {
        self.instrumentDescriptor = instrumentDescriptor
        self.storage = storage
    }
    
    public func record(value: Double) {
        record(value: value, attributes: [String: AttributeValue]())
    }
    
    public func record(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
        if value < 0 {
            print("Histograms can only record non-negative values. Instrument \(instrumentDescriptor.name) has recorded a negative value.")
            return
        }
        storage.recordDouble(value: value, attributes: attributes)
    }
}
