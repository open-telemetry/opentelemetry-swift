/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation



/// The duties of the MetricReader include:
/// - Collecting metrics from the SDK
/// - Handling the ForceFlush and Shutdown signals from the SDK
public protocol StableMetricReader : AggregationTemporalitySelectorProtocol, DefaultAggregationSelector {
    
    /// force flush handler from meter provider
    ///
    /// - Returns: success
    func forceFlush() -> ExportResult
    
    ///
    /// Provides a way to do any cleanup.
    /// - Returns: success
    func shutdown() -> ExportResult
    
    
    func register(registration: CollectionRegistration)
}

