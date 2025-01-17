//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class LongCounterSdk: LongCounter, Instrument {

    public var instrumentDescriptor: InstrumentDescriptor
    private var storage: WritableMetricStorage

    init(descriptor: InstrumentDescriptor, storage: WritableMetricStorage) {
        self.storage = storage
        self.instrumentDescriptor = descriptor
    }

    public func add(value: Int) {
        add(value: value, attribute: [String: AttributeValue]())
    }

    public func add(value: Int, attribute: [String: OpenTelemetryApi.AttributeValue]) {
        if value < 0 {
            // todo : error log
            return
        }
        storage.recordLong(value: value, attributes: attribute)
    }

}

public struct DoubleCounterSdk: DoubleCounter, Instrument {

    public var instrumentDescriptor: InstrumentDescriptor
    private var storage: WritableMetricStorage

    init(descriptor: InstrumentDescriptor, storage: WritableMetricStorage) {
        self.storage = storage
        self.instrumentDescriptor = descriptor
    }
    public mutating func add(value: Double) {
        add(value: value, attributes: [String: AttributeValue]())
    }

    public mutating func add(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
        if value < 0 {
            // todo: error log
            return
        }
        storage.recordDouble(value: value, attributes: attributes)
    }
}
