//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleUpDownCounterBuilderSdk: InstrumentBuilder, DoubleUpDownCounterBuilder {
  init(meterProviderSharedState: MeterProviderSharedState,
       meterSharedState: MeterSharedState,
       name: String,
       description: String,
       unit: String) {
    super.init(
      meterProviderSharedState: meterProviderSharedState,
      meterSharedState: meterSharedState,
      type: .upDownCounter,
      valueType: .double,
      description: description,
      unit: unit,
      instrumentName: name
    )
  }

  public func build() -> DoubleUpDownCounterSdk {
    buildSynchronousInstrument(DoubleUpDownCounterSdk.init)
  }

  public func buildWithCallback(
    _ callback: @escaping (
      ObservableMeasurementSdk
    ) -> Void
  )
    -> ObservableInstrumentSdk {
    registerDoubleAsynchronousInstrument(type: .observableUpDownCounter, updater: callback)
  }
}
