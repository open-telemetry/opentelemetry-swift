/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Observer instrument for Int values.
public protocol IntObserverMetric {
    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labelset: The labelset associated with this value.
    func observe(value: Int, labelset: LabelSet)

    /// Observes a value.
    /// - Parameters:
    ///   - value: value to observe.
    ///   - labels: The labels or dimensions associated with this value.
    /// - Returns: The bound counter metric.
    func observe(value: Int, labels: [String: String])
}

public struct NoopIntObserverMetric: IntObserverMetric {
    public init() {}

    public func observe(value: Int, labelset: LabelSet) {}

    public func observe(value: Int, labels: [String: String]) {}
}
