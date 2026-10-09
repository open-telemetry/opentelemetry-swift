//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LongHistogramMeterBuilderSdk: InstrumentBuilder, LongHistogramBuilder {
  init(meterProviderSharedState: MeterProviderSharedState,
       meterSharedState: MeterSharedState,
       instrumentName: String,
       description: String,
       unit: String) {
    super.init(
      meterProviderSharedState: meterProviderSharedState,
      meterSharedState: meterSharedState,
      type: .histogram,
      valueType: .long,
      description: description,
      unit: unit,
      instrumentName: instrumentName
    )
  }

  public func setExplicitBucketBoundariesAdvice(_ boundaries: [Double]) -> Self {
    self.explicitBucketBoundariesAdvice = boundaries
    return self
  }

  public func build() -> LongHistogramMeterSdk {
    buildSynchronousInstrument(LongHistogramMeterSdk.init)
  }
}
