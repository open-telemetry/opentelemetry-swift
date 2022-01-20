/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation



/// The duties of the MetricReader include:
/// - Collecting metrics from the SDK
/// - Handling the ForceFlush and Shutdown signals from the SDK
public protocol StableMetricReader {
    /// force flush handler from meter provider
    ///
    /// - Returns: success
    func forceFlush() -> Bool
    /// Collects the metrics from the SDK. If there are asynchronous instruments,
    /// their callbacks will be invoked.
    /// todo: extend with status: success, failed, timeout.
    /// - Returns: success
    func collect() -> Bool
    ///
    /// Provides a way to do any cleanup.
    /// - Returns: success
    func shutdown() -> Bool
}

struct NoopStableMetricReader : StableMetricReader{
    func forceFlush() -> Bool {
        true
    }

    func collect() -> Bool {
        true
    }

    func shutdown() -> Bool {
        true
    }


}
