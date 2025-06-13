/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongCounterBuilder: AnyObject {
  associatedtype AnyDoubleCounterBuilder: DoubleCounterBuilder
  associatedtype AnyLongCounter: LongCounter
  associatedtype AnyObservableLongMeasurement: ObservableLongMeasurement
  associatedtype AnyObservableLongCounter: ObservableLongCounter

  func ofDoubles() -> AnyDoubleCounterBuilder
  func build() -> AnyLongCounter
  func buildWithCallback(_ callback: @escaping (AnyObservableLongMeasurement) -> Void) -> AnyObservableLongCounter
}
