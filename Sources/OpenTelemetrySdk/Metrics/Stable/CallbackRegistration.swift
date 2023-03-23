//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct CallbackRegistration {
    var observableMeasurements = [StableObservableMeasurementSdk]()
    var callback : ()->()
    var instrumentDescriptors : [InstrumentDescriptor]
    var hasStorages : Bool
    init(observableMeasurements: [StableObservableMeasurementSdk], callback: @escaping () -> Void) {
        self.observableMeasurements = observableMeasurements
        self.callback = callback
        self.instrumentDescriptors = observableMeasurements.map { measurement in
            return measurement.descriptor
        }
        self.hasStorages = !observableMeasurements.map { measurement in
            measurement.storages
            
        }.isEmpty
    }
    
    public mutating func execute(reader : RegisteredReader, startEpochNanos : UInt64, epochNanos : UInt64) {
        if !hasStorages {
            return
        }
        for var measurement in observableMeasurements {
            measurement.setActiveReader(reader: reader, startEpochNanos: startEpochNanos, epochNanos: epochNanos)
        }
        callback()
        for var measurement in observableMeasurements {
            measurement.clearActiveReader()
        }
    }
}

