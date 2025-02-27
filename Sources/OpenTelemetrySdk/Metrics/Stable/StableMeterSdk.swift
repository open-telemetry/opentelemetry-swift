/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class StableMeterSdk: StableMeter {
  var meterProviderSharedState: MeterProviderSharedState
  var meterSharedState: StableMeterSharedState
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo

  init(meterProviderSharedState: inout MeterProviderSharedState,
       instrumentScope: InstrumentationScopeInfo,
       registeredReaders: inout [RegisteredReader]) {
    self.instrumentationScopeInfo = instrumentScope
    self.meterProviderSharedState = meterProviderSharedState
    self.meterSharedState = StableMeterSharedState(instrumentationScope: instrumentScope,
                                                   registeredReaders: registeredReaders)
  }

  func counterBuilder(name: String) -> OpenTelemetryApi.LongCounterBuilder {
    return LongCounterMeterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                      meterSharedState: &meterSharedState,
                                      name: name)
  }

  func upDownCounterBuilder(name: String) -> OpenTelemetryApi.LongUpDownCounterBuilder {
    return LongUpDownCounterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                       meterSharedState: &meterSharedState,
                                       name: name)
  }

  func histogramBuilder(name: String) -> OpenTelemetryApi.DoubleHistogramBuilder {
    return DoubleHistogramMeterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                          meterSharedState: &meterSharedState,
                                          name: name)
  }

  func gaugeBuilder(name: String) -> OpenTelemetryApi.DoubleGaugeBuilder {
    DoubleGaugeBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                          meterSharedState: &meterSharedState,
                          name: name)
  }

  fileprivate let collectLock = Lock()

  func collectAll(registerReader: RegisteredReader, epochNanos: UInt64) -> [StableMetricData] {
    meterSharedState.collectAll(registeredReader: registerReader, meterProviderSharedState: meterProviderSharedState, epochNanos: epochNanos)
  }
}
