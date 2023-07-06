//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class LongCounterMeterBuilderSdk : LongCounterBuilder, InstrumentBuilder {
    
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: StableMeterSharedState
    
    var type: InstrumentType
    
    var valueType: InstrumentValueType
    
    var description: String = ""
    
    var unit: String = ""
    
    var instrumentName: String
    
    internal init(meterProviderSharedState: inout MeterProviderSharedState, meterSharedState: inout StableMeterSharedState, name: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.instrumentName = name
        type = .counter
        valueType = .long
        
    }
    
    public func ofDoubles() -> OpenTelemetryApi.DoubleCounterBuilder {
        swapBuilder(DoubleCounterMeterBuilderSdk.init)
    }
    
    public func build() -> OpenTelemetryApi.LongCounter {
        return buildSynchronousInstrument(LongCounterSdk.init)
    }
    
    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableLongMeasurement) -> Void) -> OpenTelemetryApi.ObservableLongCounter {
        registerLongAsynchronousInstrument(type: type, updater: callback)
    }
    
    
}

