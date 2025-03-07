//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongUpDownCounterBuilderSdk: InstrumentBuilder, LongUpDownCounterBuilder {
  init(meterProviderSharedState: inout MeterProviderSharedState,
       meterSharedState: inout StableMeterSharedState,
       name: String) {
    super.init(
      meterProviderSharedState: &meterProviderSharedState,
      meterSharedState: &meterSharedState,
      type: .upDownCounter,
      valueType: .long,
      description: "",
      unit: "",
      instrumentName: name
    )
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
