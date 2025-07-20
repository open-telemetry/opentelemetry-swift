/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "MeterSdk")
public typealias StableMeterSdk = MeterSdk

public class MeterSdk: Meter {
  var meterProviderSharedState: MeterProviderSharedState
  let meterSharedState: Locked<MeterSharedState>
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo

  init(meterProviderSharedState: MeterProviderSharedState,
       instrumentScope: InstrumentationScopeInfo,
       registeredReaders: [RegisteredReader]) {
    instrumentationScopeInfo = instrumentScope
    self.meterProviderSharedState = meterProviderSharedState
    self.meterSharedState = .init(initialValue: MeterSharedState(instrumentationScope: instrumentScope,
                                              registeredReaders: registeredReaders))
  }

  public func counterBuilder(name: String) -> LongCounterMeterBuilderSdk {
    return LongCounterMeterBuilderSdk(meterProviderSharedState: meterProviderSharedState,
                                      meterSharedState: meterSharedState.protectedValue,
                                      name: name)
  }

  public func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilderSdk {
    return LongUpDownCounterBuilderSdk(meterProviderSharedState: meterProviderSharedState,
                                       meterSharedState: meterSharedState.protectedValue,
                                       name: name)
  }

  public func histogramBuilder(name: String) -> DoubleHistogramMeterBuilderSdk {
    return DoubleHistogramMeterBuilderSdk(meterProviderSharedState: meterProviderSharedState,
                                          meterSharedState: meterSharedState.protectedValue,
                                          name: name)
  }

  public func gaugeBuilder(name: String) -> DoubleGaugeBuilderSdk {
    DoubleGaugeBuilderSdk(meterProviderSharedState: meterProviderSharedState,
                          meterSharedState: meterSharedState.protectedValue,
                          name: name)
  }

  fileprivate let collectLock = Lock()

  func collectAll(registerReader: RegisteredReader, epochNanos: UInt64) -> [MetricData] {
    meterSharedState.protectedValue.collectAll(registeredReader: registerReader, meterProviderSharedState: meterProviderSharedState, epochNanos: epochNanos)
  }
}
