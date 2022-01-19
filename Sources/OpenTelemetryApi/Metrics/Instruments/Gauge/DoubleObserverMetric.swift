/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Observer instrument for Double values.
public protocol DoubleObserverMetric {
    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labelset: The labelset associated with this value.
    func observe(value: Double, labelset: LabelSet)

    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound counter metric.
    func observe(value: Double, labels: [String: String])
}

public struct NoopDoubleObserverMetric: DoubleObserverMetric {
    public init() {}

    public func observe(value: Double, labelset: LabelSet) {}

    public func observe(value: Double, labels: [String: String]) {}
}
