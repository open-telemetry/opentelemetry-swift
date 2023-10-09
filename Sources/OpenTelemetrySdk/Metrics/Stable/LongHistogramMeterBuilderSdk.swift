//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongHistogramMeterBuilderSdk: LongHistogramBuilder, InstrumentBuilder {
    var meterProviderSharedState: MeterProviderSharedState
    
    var meterSharedState: StableMeterSharedState
    
    let type: InstrumentType = .histogram
    
    let valueType: InstrumentValueType = .long
    
    var description: String
    
    var unit: String
    
    var instrumentName: String
    
    internal init(meterProviderSharedState: MeterProviderSharedState,
                  meterSharedState: StableMeterSharedState,
                  instrumentName: String,
                  description: String,
                  unit: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.instrumentName = instrumentName
        self.description = description
        self.unit = unit
    }
    
    public func build() -> OpenTelemetryApi.LongHistogram {
        buildSynchronousInstrument(LongHistogramMeterSdk.init)
    }
}
