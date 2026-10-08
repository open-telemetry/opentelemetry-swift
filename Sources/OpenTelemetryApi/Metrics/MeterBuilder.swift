/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol MeterBuilder: AnyObject {
  associatedtype AnyMeter: Meter
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

  /// Assign a set of attributes that will be applied to the Meter.
  ///
  /// - Parameter attributes: key/value-pair of attributes
  /// - Returns: self
  func setAttributes(attributes: [String: AttributeValue]) -> Self

  /// gets or creates a Meter
  ///
  /// - Returns: a Meter configured with the provided options.
  func build() -> AnyMeter
}
