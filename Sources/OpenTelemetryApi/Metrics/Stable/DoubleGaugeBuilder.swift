/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleGaugeBuilder: AnyObject {
  associatedtype AnyLongGaugeBuilder: LongGaugeBuilder
  associatedtype AnyDoubleGauge: DoubleGauge
  associatedtype AnyObservableDoubleMeasurement: ObservableDoubleMeasurement
  associatedtype AnyObservableDoubleGauge: ObservableDoubleGauge
  func ofLongs() -> AnyLongGaugeBuilder
  func build() -> AnyDoubleGauge
  func buildWithCallback(_ callback: @escaping (AnyObservableDoubleMeasurement) -> Void) -> AnyObservableDoubleGauge
}
