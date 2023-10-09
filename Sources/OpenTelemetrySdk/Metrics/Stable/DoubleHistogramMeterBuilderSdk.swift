//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleHistogramMeterBuilderSdk: DoubleHistogramBuilder, InstrumentBuilder {
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: StableMeterSharedState
    
    let type: InstrumentType = .histogram
    
    let valueType: InstrumentValueType = .double
    
    let instrumentName: String
    
    var description: String
    
    var unit: String
    
    init(meterProviderSharedState: inout MeterProviderSharedState,
         meterSharedState: inout StableMeterSharedState,
         name: String,
         description: String = "",
         unit: String = "") {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.instrumentName = name
        self.description = description
        self.unit = unit
    }

    public func ofLongs() -> OpenTelemetryApi.LongHistogramBuilder {
        swapBuilder(LongHistogramMeterBuilderSdk.init)
    }
    
    public func build() -> OpenTelemetryApi.DoubleHistogram {
        buildSynchronousInstrument(DoubleHistogramMeterSdk.init)
    }
}
