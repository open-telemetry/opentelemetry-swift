/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleGaugeBuilder: AnyObject {
  func ofLongs() -> LongGaugeBuilder
  func build() -> DoubleGauge
  func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleGauge
}
