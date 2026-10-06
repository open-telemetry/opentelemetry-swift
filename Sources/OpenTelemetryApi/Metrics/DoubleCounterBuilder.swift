/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleCounterBuilder: AnyObject {
  associatedtype AnyDoubleCounter: DoubleCounter
  associatedtype AnyObservableDoubleCounter: ObservableDoubleCounter
  associatedtype AnyObservableDoubleMeasurement: ObservableDoubleMeasurement

  func build() -> AnyDoubleCounter
  func buildWithCallback(_ callback: @escaping (AnyObservableDoubleMeasurement) -> Void) -> AnyObservableDoubleCounter
}
