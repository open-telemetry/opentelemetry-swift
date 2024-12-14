//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongUpDownCounterBuilderSdk: LongUpDownCounterBuilder, InstrumentBuilder {
    var meterSharedState: StableMeterSharedState

    var meterProviderSharedState: MeterProviderSharedState

    let type: InstrumentType = .upDownCounter

    let valueType: InstrumentValueType = .long

    var instrumentName: String

    var description: String = ""

    var unit: String = ""

    init(meterProviderSharedState: inout MeterProviderSharedState,
         meterSharedState: inout StableMeterSharedState,
         name: String) {
        self.meterSharedState = meterSharedState
        self.meterProviderSharedState = meterProviderSharedState
        self.instrumentName = name
    }

    public func ofDoubles() -> OpenTelemetryApi.DoubleUpDownCounterBuilder {
        swapBuilder(DoubleUpDownCounterBuilderSdk.init)
    }

    public func build() -> OpenTelemetryApi.LongUpDownCounter {
        buildSynchronousInstrument(LongUpDownCounterSdk.init)
    }

    public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableLongMeasurement) -> Void)
        -> OpenTelemetryApi.ObservableLongUpDownCounter {
        registerLongAsynchronousInstrument(type: .observableUpDownCounter, updater: callback)
    }
}
