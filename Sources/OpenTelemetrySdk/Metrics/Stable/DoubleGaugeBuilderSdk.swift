//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleGaugeBuilderSdk: InstrumentBuilder, DoubleGaugeBuilder {
  init(meterProviderSharedState: inout MeterProviderSharedState, meterSharedState: inout StableMeterSharedState, name: String) {
    super.init(
      meterProviderSharedState: &meterProviderSharedState,
      meterSharedState: &meterSharedState,
      type: .observableGauge,
      valueType: .double,
      description: "",
      unit: "",
      instrumentName: name
    )
  }

  public func ofLongs() -> OpenTelemetryApi.LongGaugeBuilder {
    swapBuilder(LongGaugeBuilderSdk.init)
  }

  public func build() -> DoubleGauge {
    type = .gauge
    return buildSynchronousInstrument(DoubleGaugeSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (OpenTelemetryApi.ObservableDoubleMeasurement) -> Void) -> OpenTelemetryApi.ObservableDoubleGauge {
    type = .observableGauge
    return registerDoubleAsynchronousInstrument(type: type, updater: callback)
  }
}
