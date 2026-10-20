//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleHistogramMeterBuilderSdk: InstrumentBuilder, DoubleHistogramBuilder {
  init(meterProviderSharedState: MeterProviderSharedState,
       meterSharedState: MeterSharedState,
       name: String,
       description: String = "",
       unit: String = "") {
    super.init(
      meterProviderSharedState: meterProviderSharedState,
      meterSharedState: meterSharedState,
      type: .histogram,
      valueType: .double,
      description: description,
      unit: unit,
      instrumentName: name
    )
  }

  public func setExplicitBucketBoundariesAdvice(_ boundaries: [Double]) -> Self {
    self.explicitBucketBoundariesAdvice = boundaries
    return self
  }

  public func ofLongs() -> LongHistogramMeterBuilderSdk {
    swapBuilder(LongHistogramMeterBuilderSdk.init)
  }

  public func build() -> DoubleHistogramMeterSdk {
    buildSynchronousInstrument(DoubleHistogramMeterSdk.init)
  }
}
