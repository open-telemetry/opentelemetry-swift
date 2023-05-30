//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct DoubleGaugeBuilderSdk : DoubleGaugeBuilder, InstrumentBuilder {

    
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: StableMeterSharedState
    
    var type: InstrumentType = .observableGauge
    
    var valueType: InstrumentValueType = .double
    
    var description: String = ""
    
    var unit: String = ""
    
    var instrumentName: String
    
    
    init(meterProviderSharedState: inout MeterProviderSharedState, meterSharedState : inout StableMeterSharedState, name: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        instrumentName = name
    }
    
    public func ofLongs() -> OpenTelemetryApi.LongGaugeBuilder {
        swapBuilder(LongGaugeBuilderSdk.init)
    }
    
    mutating public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void) -> OpenTelemetryApi.ObservableDoubleGauge {
        registerDoubleAsynchronousInstrument(type: type, updater: callback)
    }
    
}
