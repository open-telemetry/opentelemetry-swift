//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleCounterMeterBuilderSdk: InstrumentBuilder, DoubleCounterBuilder {
  init(meterProviderSharedState: inout MeterProviderSharedState,
       meterSharedState: inout StableMeterSharedState,
       name: String,
       description: String,
       unit: String) {
    super.init(
      meterProviderSharedState: &meterProviderSharedState,
      meterSharedState: &meterSharedState,
      type: .counter,
      valueType: .double,
      description: description,
      unit: unit,
      instrumentName: name
    )
  }

  public func build() -> DoubleCounterSdk {
    buildSynchronousInstrument(DoubleCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (StableObservableMeasurementSdk) -> Void)
    -> ObservableInstrumentSdk {
    registerDoubleAsynchronousInstrument(type: .observableCounter, updater: callback)
  }
}
