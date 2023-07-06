/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Main interface to obtain metric instruments.
/// Replaces Meter class. After a deprecation period StableMeter will be renamed to Meter
///
public protocol StableMeter {
    func counterBuilder(name : String) -> LongCounterBuilder
    func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilder
    func histogramBuilder(name: String) -> DoubleHistogramBuilder
    func gaugeBuilder(name: String) -> DoubleGaugeBuilder
}


