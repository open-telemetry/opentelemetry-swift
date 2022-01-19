/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Creates Meters for an instrumentation library.
/// Libraries should use this class as follows to obtain Meter instance.
public protocol StableMeterProvider: AnyObject {
    /// Returns a Meter for a given name and version.
    /// - Parameters:
    ///   - name: Name of the instrumentation library.
    ///   - version: Version of the instrumentation library (optional).
    ///   - schema: specifies the schema URL that should be recorded in the emitted telemetry (optional).
    /// - Returns: Meter for the given name and version information.
    func get(name: String, version: String?, schema: String?) -> StableMeter
}
