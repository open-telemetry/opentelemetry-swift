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

  public func ofDoubles() -> DoubleCounterMeterBuilderSdk {
    swapBuilder(DoubleCounterMeterBuilderSdk.init)
  }

  public func build() -> LongCounterSdk {
    return buildSynchronousInstrument(LongCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (StableObservableMeasurementSdk) -> Void)
    -> ObservableInstrumentSdk {
    registerLongAsynchronousInstrument(type: .observableCounter, updater: callback)
  }
}
