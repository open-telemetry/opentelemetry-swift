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

  public func build() -> OpenTelemetryApi.DoubleCounter {
    buildSynchronousInstrument(DoubleCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void)
    -> OpenTelemetryApi.ObservableDoubleCounter {
    registerDoubleAsynchronousInstrument(type: .observableCounter, updater: callback)
  }
}
