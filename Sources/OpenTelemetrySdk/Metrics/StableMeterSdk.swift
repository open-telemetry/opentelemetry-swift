/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class StableMeterSdk: StableMeter {
  var meterProviderSharedState: MeterProviderSharedState
  var meterSharedState: StableMeterSharedState
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo

  init(meterProviderSharedState: inout MeterProviderSharedState,
       instrumentScope: InstrumentationScopeInfo,
       registeredReaders: inout [RegisteredReader]) {
    instrumentationScopeInfo = instrumentScope
    self.meterProviderSharedState = meterProviderSharedState
    meterSharedState = StableMeterSharedState(instrumentationScope: instrumentScope,
                                              registeredReaders: registeredReaders)
  }

  public func counterBuilder(name: String) -> LongCounterMeterBuilderSdk {
    return LongCounterMeterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                      meterSharedState: &meterSharedState,
                                      name: name)
  }

  public func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilderSdk {
    return LongUpDownCounterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                       meterSharedState: &meterSharedState,
                                       name: name)
  }

  public func histogramBuilder(name: String) -> DoubleHistogramMeterBuilderSdk {
    return DoubleHistogramMeterBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                                          meterSharedState: &meterSharedState,
                                          name: name)
  }

  public func gaugeBuilder(name: String) -> DoubleGaugeBuilderSdk {
    DoubleGaugeBuilderSdk(meterProviderSharedState: &meterProviderSharedState,
                          meterSharedState: &meterSharedState,
                          name: name)
  }

  fileprivate let collectLock = Lock()

  func collectAll(registerReader: RegisteredReader, epochNanos: UInt64) -> [StableMetricData] {
    meterSharedState.collectAll(registeredReader: registerReader, meterProviderSharedState: meterProviderSharedState, epochNanos: epochNanos)
  }
}
