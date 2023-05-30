/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Creates Meters for an instrumentation library.
/// Libraries should use this class as follows to obtain Meter instance.
// Phase 2
//@available(*, deprecated, renamed: "StableMeterProvider")
public protocol MeterProvider: AnyObject {
    /// Returns a Meter for a given name and version.
    /// - Parameters:
    ///   - instrumentationName: Name of the instrumentation library.
    ///   - instrumentationVersion: Version of the instrumentation library (optional).
    /// - Returns: Meter for the given name and version information.
    // Phase 2
    //@available(*, deprecated, renamed: "StableMeterProvider.get(name:version:schema_url:)")
    func get(instrumentationName: String, instrumentationVersion: String?) -> Meter
}
