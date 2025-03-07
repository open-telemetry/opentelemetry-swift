//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongCounterMeterBuilderSdk: InstrumentBuilder, LongCounterBuilder {
  init(meterProviderSharedState: inout MeterProviderSharedState,
       meterSharedState: inout StableMeterSharedState,
       name: String) {
    super.init(
      meterProviderSharedState: &meterProviderSharedState,
      meterSharedState: &meterSharedState,
      type: .counter,
      valueType: .long,
      description: "",
      unit: "",
      instrumentName: name
    )
  }

  public func ofDoubles() -> OpenTelemetryApi.DoubleCounterBuilder {
    swapBuilder(DoubleCounterMeterBuilderSdk.init)
  }

  public func build() -> OpenTelemetryApi.LongCounter {
    return buildSynchronousInstrument(LongCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableLongMeasurement) -> Void)
    -> OpenTelemetryApi.ObservableLongCounter {
    registerLongAsynchronousInstrument(type: .observableCounter, updater: callback)
  }
}
