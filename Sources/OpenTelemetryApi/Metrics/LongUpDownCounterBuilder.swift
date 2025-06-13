/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongUpDownCounterBuilder: AnyObject {
  associatedtype AssociatedDoubleUpDownCounterBuilder: DoubleUpDownCounterBuilder
  associatedtype AssociatedLongUpDownCounter: LongUpDownCounter
  associatedtype AssociatedObservableLongMeasurement: ObservableLongMeasurement
  associatedtype AssociatedObservableLongUpDownCounter: ObservableLongUpDownCounter
  func ofDoubles() -> AssociatedDoubleUpDownCounterBuilder
  func build() -> AssociatedLongUpDownCounter
  func buildWithCallback(_ callback: @escaping (AssociatedObservableLongMeasurement) -> Void) -> AssociatedObservableLongUpDownCounter
}
