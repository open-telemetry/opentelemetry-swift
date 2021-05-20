/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Creates Meters for an instrumentation library.
/// Libraries should use this class as follows to obtain Meter instance.
public protocol MeterProvider: AnyObject {
    /// Returns a Meter for a given name and version.
    /// - Parameters:
    ///   - instrumentationName: Name of the instrumentation library.
    ///   - instrumentationVersion: Version of the instrumentation library (optional).
    /// - Returns: Meter for the given name and version information.
    func get(instrumentationName: String, instrumentationVersion: String?) -> Meter
}
