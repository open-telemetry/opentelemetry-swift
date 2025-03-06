/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleCounterBuilder: AnyObject {
  func build() -> DoubleCounter

  func setUnit(_ unit: String) -> Self

  func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleCounter
}
