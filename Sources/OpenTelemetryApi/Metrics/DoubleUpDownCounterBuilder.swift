/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleUpDownCounterBuilder: AnyObject {
  associatedtype AnyDoubleUpDownCounter: DoubleUpDownCounter
  associatedtype AnyObservableDoubleUpDownCounter: ObservableDoubleUpDownCounter
  associatedtype AnyObservableDoubleMeasurement: ObservableDoubleMeasurement
  func build() -> AnyDoubleUpDownCounter
  func buildWithCallback(_ callback: @escaping (AnyObservableDoubleMeasurement) -> Void) -> AnyObservableDoubleUpDownCounter
}
