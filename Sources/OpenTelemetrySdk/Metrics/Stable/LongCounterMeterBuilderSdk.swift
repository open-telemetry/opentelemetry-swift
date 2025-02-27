//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongCounterMeterBuilderSdk: LongCounterBuilder, InstrumentBuilder {
  var meterProviderSharedState: MeterProviderSharedState

  var meterSharedState: StableMeterSharedState

  let type: InstrumentType = .counter

  let valueType: InstrumentValueType = .long

  var instrumentName: String

  var description: String = ""

  var unit: String = ""

  init(meterProviderSharedState: inout MeterProviderSharedState,
       meterSharedState: inout StableMeterSharedState,
       name: String) {
    self.meterProviderSharedState = meterProviderSharedState
    self.meterSharedState = meterSharedState
    self.instrumentName = name
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
