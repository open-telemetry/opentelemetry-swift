//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleUpDownCounterBuilderSdk: DoubleUpDownCounterBuilder, InstrumentBuilder {
  var meterSharedState: StableMeterSharedState

  var meterProviderSharedState: MeterProviderSharedState

  let type: InstrumentType = .upDownCounter

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
    instrumentName = name
  }

  public func build() -> OpenTelemetryApi.DoubleUpDownCounter {
    buildSynchronousInstrument(DoubleUpDownCounterSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void)
    -> OpenTelemetryApi.ObservableDoubleUpDownCounter {
    registerDoubleAsynchronousInstrument(type: .observableUpDownCounter, updater: callback)
  }
}
