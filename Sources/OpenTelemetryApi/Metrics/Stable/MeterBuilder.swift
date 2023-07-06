/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol MeterBuilder : AnyObject {

    /// Assign an OpenTelemetry schema URL to the resulting Meter
    ///
    /// - Parameter schemaUrl: the URL of the OpenTelemetry schema being used by this instrumentation scope
    /// - Returns: self
    func setSchemaUrl(schemaUrl: String) -> Self

    /// Assign a version to the instrumentation scope that is used in the resulting Meter.
    ///
    /// - Parameter instrumentationVersion: the version of the instrumentation scope.
    /// - Returns: self
    func setInstrumentationVersion(instrumentationVersion: String) -> Self


    /// gets or creates a Meter
    ///
    /// - Returns: a Meter configured with the provided options.
    func build() -> StableMeter

}
