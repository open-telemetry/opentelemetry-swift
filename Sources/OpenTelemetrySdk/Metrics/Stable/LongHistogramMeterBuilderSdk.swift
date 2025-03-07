//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongHistogramMeterBuilderSdk: InstrumentBuilder, LongHistogramBuilder {
  init(meterProviderSharedState: inout MeterProviderSharedState,
       meterSharedState: inout StableMeterSharedState,
       instrumentName: String,
       description: String,
       unit: String) {
    super.init(
      meterProviderSharedState: &meterProviderSharedState,
      meterSharedState: &meterSharedState,
      type: .histogram,
      valueType: .long,
      description: description,
      unit: unit,
      instrumentName: instrumentName
    )
  }

  public func build() -> OpenTelemetryApi.LongHistogram {
    buildSynchronousInstrument(LongHistogramMeterSdk.init)
  }
}
