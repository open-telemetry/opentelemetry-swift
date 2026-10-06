//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongGaugeBuilderSdk: InstrumentBuilder, LongGaugeBuilder {
  init(meterProviderSharedState: MeterProviderSharedState, meterSharedState: MeterSharedState, name: String, description: String, unit: String) {
    super.init(
      meterProviderSharedState: meterProviderSharedState,
      meterSharedState: meterSharedState,
      type: .observableGauge,
      valueType: .long,
      description: description,
      unit: unit,
      instrumentName: name
    )
  }

  public func build() -> LongGaugeSdk {
    type = .gauge
    return buildSynchronousInstrument(LongGaugeSdk.init)
  }

  public func buildWithCallback(_ callback: @escaping (ObservableMeasurementSdk) -> Void) -> ObservableInstrumentSdk {
    type = .observableGauge
    return registerLongAsynchronousInstrument(type: type, updater: callback)
  }
}
