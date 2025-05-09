/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongGaugeBuilder: AnyObject {
  associatedtype AssociatedLongGuage: LongGauge
  associatedtype AssociatedObservableLongMeasurement: ObservableLongMeasurement
  associatedtype AssociatedObservableLongGauge: ObservableLongGauge
  func build() -> AssociatedLongGuage
  func buildWithCallback(_ callback: @escaping (AssociatedObservableLongMeasurement) -> Void) -> AssociatedObservableLongGauge
}
