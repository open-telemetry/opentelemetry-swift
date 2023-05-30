/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Handle to the metrics observer
public protocol DoubleObserverMetricHandle {
    /// Observes the given value.
    /// - Parameters:
    ///   - value: value by which the observer handle should be Recorded.
    func observe(value: Double)
}
