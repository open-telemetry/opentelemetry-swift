/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Creates Meters for an instrumentation library.
/// Libraries should use this class as follows to obtain Meter instance.

@available(*, deprecated, renamed: "MeterProvider")
public typealias StableMeterProvider = MeterProvider

public protocol MeterProvider: AnyObject {
  associatedtype AnyMeter: Meter
  associatedtype AnyMeterBuilder: MeterBuilder
  /// Returns a Meter for a given name and version.
  /// - Parameters:
  ///   - name: Name of the instrumentation library.
  /// - Returns: Meter for the given name and version information.
  func get(name: String) -> AnyMeter

  func meterBuilder(name: String) -> AnyMeterBuilder
}
