/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A factory for creating named Tracers.
public protocol TracerProvider {
  /// Gets or creates a named tracer instance.
  /// - Parameters:
  ///   - instrumentationName: the name of the instrumentation library, not the name of the instrumented library
  ///   - instrumentationVersion:  The version of the instrumentation library (e.g., "semver:1.0.0"). Optional
  ///   - schemaUrl: The schema url. Optional
  ///   - attributes: attributes to be associated with span created by this tracer. Optional
  func get(
    instrumentationName: String,
    instrumentationVersion: String?,
    schemaUrl: String?,
    attributes: [String: AttributeValue]?
  ) -> any Tracer
}

public extension TracerProvider {
  func get(instrumentationName: String,
           instrumentationVersion: String? = nil,
           schemaUrl: String? = nil,
           attributes: [String: AttributeValue]? = nil) -> any Tracer {
    return get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion,
      schemaUrl: schemaUrl,
      attributes: attributes
    )
  }
}
