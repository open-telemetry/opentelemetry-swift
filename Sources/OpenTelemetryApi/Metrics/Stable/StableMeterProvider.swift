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
    /// - Returns: Meter for the given name and version information.
    func get(name: String) -> StableMeter

    func meterBuilder(name: String) -> MeterBuilder

}

