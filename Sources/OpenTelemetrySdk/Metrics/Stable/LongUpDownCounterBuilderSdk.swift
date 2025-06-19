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

  public func ofDoubles() -> DoubleUpDownCounterBuilderSdk {
    swapBuilder(DoubleUpDownCounterBuilderSdk.init)
  }

  public func build() -> LongUpDownCounterSdk {
    buildSynchronousInstrument(LongUpDownCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (StableObservableMeasurementSdk) -> Void)
    -> ObservableInstrumentSdk {
    registerLongAsynchronousInstrument(type: .observableUpDownCounter, updater: callback)
  }
}
