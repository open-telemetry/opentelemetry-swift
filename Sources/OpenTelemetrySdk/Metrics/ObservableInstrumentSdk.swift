//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public struct ObservableInstrumentSdk: ObservableDoubleCounter, ObservableLongCounter, ObservableLongGauge, ObservableLongUpDownCounter, ObservableDoubleGauge, ObservableDoubleUpDownCounter {
  let meterSharedState: MeterSharedState
  let callbackRegistration: CallbackRegistration

  // todo: Java implementation uses closeables to remove this from the meterSharedState.callback Registation. investigate alternative?
  public func close() {
    meterSharedState.removeCallback(callback: callbackRegistration)
  }
}
