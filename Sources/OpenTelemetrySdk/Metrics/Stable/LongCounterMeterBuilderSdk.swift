//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct LongCounterMeterBuilderSdk : LongCounterBuilder, InstrumentBuilder {
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: MeterSharedState
    
    var type: InstrumentType
    
    var valueType: InstrumentValueType
    
    var description: String = ""
    
    var unit: String = ""
    
    var instrumentName: String
    
    init(meterProviderSharedState: MeterProviderSharedState, meterSharedState: MeterSharedState, name: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.instrumentName = name
        type = .counter
        valueType = .long
        
    }
    
    public func ofDoubles() -> OpenTelemetryApi.DoubleCounterBuilder {
        return DoubleCounterBuilderSdk(meterProviderShared, meterSharedState, instrumentName, description, unit)
    }
    
    public func build() -> OpenTelemetryApi.LongCounter {
        
    }
    
    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableLongMeasurement) -> Void) -> OpenTelemetryApi.ObservableLongCounter {
        <#code#>
    }
}

