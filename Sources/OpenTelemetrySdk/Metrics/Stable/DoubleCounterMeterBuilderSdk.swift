//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleCounterMeterBuilderSdk: DoubleCounterBuilder, InstrumentBuilder {
    var meterSharedState: StableMeterSharedState

    var meterProviderSharedState: MeterProviderSharedState

    let type: InstrumentType = .counter

    let valueType: InstrumentValueType = .double

    var instrumentName: String

    var description: String

    var unit: String

    init(meterProviderSharedState: MeterProviderSharedState,
         meterSharedState: StableMeterSharedState,
         name: String,
         description: String,
         unit: String) {
        self.meterProviderSharedState = meterProviderSharedState
        self.meterSharedState = meterSharedState
        self.unit = unit
        self.description = description
        self.instrumentName = name
    }

    public func build() -> OpenTelemetryApi.DoubleCounter {
        buildSynchronousInstrument(DoubleCounterSdk.init)
    }

    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void)
        -> OpenTelemetryApi.ObservableDoubleCounter {
        registerDoubleAsynchronousInstrument(type: .observableCounter, updater: callback)
    }
}
