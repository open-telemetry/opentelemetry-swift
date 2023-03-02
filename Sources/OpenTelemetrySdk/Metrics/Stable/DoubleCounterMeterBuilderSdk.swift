//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct DoubleCounterMeterBuilderSdk : DoubleCounterBuilder, InstrumentBuilder {
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: MeterSharedState
    
    let type: InstrumentType = .counter
    
    let valueType: InstrumentValueType = .double
    
    var description: String
    
    var unit: String
    
    var instrumentName: String
    
    init(meterProviderSharedState : MeterProviderSharedState, meterSharedState : MeterSharedState, name : String, description: String, unit: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.unit = unit
        self.description = description
        self.instrumentName  = name
    }
    
    public func build() -> OpenTelemetryApi.DoubleCounter {

    }
    
    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void) -> OpenTelemetryApi.ObservableDoubleCounter {
        
    }
    

    
    
}
