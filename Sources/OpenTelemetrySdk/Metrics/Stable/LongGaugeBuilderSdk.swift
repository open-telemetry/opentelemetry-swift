//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi
public class LongGaugeBuilderSdk : LongGaugeBuilder, InstrumentBuilder {
    
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: StableMeterSharedState
    
    var type: InstrumentType = .observableGauge
    
    var valueType: InstrumentValueType = .long
    
    var description: String = ""
    
    var unit: String = ""
    
    var instrumentName: String
    
    
    internal init(meterProviderSharedState: MeterProviderSharedState, meterSharedState : StableMeterSharedState, name: String, description: String, unit: String) {
        instrumentName = name
        self.unit = unit
        self.description = description
        self.meterSharedState = meterSharedState
        self.meterProviderSharedState = meterProviderSharedState
    }
    
    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableLongMeasurement) -> Void) -> OpenTelemetryApi.ObservableLongGauge {
        registerLongAsynchronousInstrument(type: type, updater: callback)
    }
    
    public func setDescription(_ description: String) -> LongGaugeBuilder {
        self.description = description
        return self
    }
    
    public func setUnit(_ unit: String) -> LongGaugeBuilder {
        self.unit = unit
        return self
    }
}
