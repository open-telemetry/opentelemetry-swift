/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A factory for creating named Tracers.
public protocol TracerProviderBase {
    /// Gets or creates a named tracer instance.
    /// - Parameters:
    ///   - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
    ///   - instrumentationVersion:  The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
    func getBase(instrumentationName: String, instrumentationVersion: String?) -> TracerBase
}

/// A factory for creating named Tracers.
public protocol TracerProvider: TracerProviderBase {
    /// Gets or creates a named tracer instance.
    /// - Parameters:
    ///   - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
    ///   - instrumentationVersion:  The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
    func get(instrumentationName: String, instrumentationVersion: String?) -> Tracer
}

public extension TracerProvider {
    func getBase(instrumentationName: String, instrumentationVersion: String?) -> TracerBase {
        self.get(instrumentationName: instrumentationName, instrumentationVersion: instrumentationVersion)
    }
}

extension TracerProvider {
    func get(instrumentationName: String) -> Tracer {
        return get(instrumentationName: instrumentationName, instrumentationVersion: nil)
    }
}
