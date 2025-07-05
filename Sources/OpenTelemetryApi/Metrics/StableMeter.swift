/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Main interface to obtain metric instruments.
/// Replaces Meter class. After a deprecation period StableMeter will be renamed to Meter
///
public protocol StableMeter {
  associatedtype AssociatedCounterBuilder: LongCounterBuilder
  associatedtype AssociatedLongUpDownCounterBuilder: LongUpDownCounterBuilder
  associatedtype AssociatedDoubleHistogramBuilder: DoubleHistogramBuilder
  associatedtype AssociatedDoubleGaugeBuilder: DoubleGaugeBuilder
  func counterBuilder(name: String) -> AssociatedCounterBuilder
  func upDownCounterBuilder(name: String) -> AssociatedLongUpDownCounterBuilder
  func histogramBuilder(name: String) -> AssociatedDoubleHistogramBuilder
  func gaugeBuilder(name: String) -> AssociatedDoubleGaugeBuilder
}
