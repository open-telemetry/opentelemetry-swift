/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleCounterBuilder: AnyObject {
  associatedtype AnyDoubleCounter: DoubleCounter
  associatedtype AnyObservableDoubleCounter: ObservableDoubleCounter
  associatedtype AnyObservableDoubleMeasurement: ObservableDoubleMeasurement

  /// Sets the unit of the instrument.
  ///
  /// - Parameter unit: The unit of measure, for example `s` or `By`.
  /// - Returns: Self for method chaining
  func setUnit(_ unit: String) -> Self

  /// Sets the description of the instrument.
  ///
  /// - Parameter description: A human-readable description of the instrument.
  /// - Returns: Self for method chaining
  func setDescription(_ description: String) -> Self

  func build() -> AnyDoubleCounter
  func buildWithCallback(_ callback: @escaping (AnyObservableDoubleMeasurement) -> Void) -> AnyObservableDoubleCounter
}

/// Default implementations that ignore the value, so conforming types written before these
/// requirements existed keep compiling. Implementations that export metrics should override them.
public extension DoubleCounterBuilder {
  func setUnit(_ unit: String) -> Self {
    self
  }

  func setDescription(_ description: String) -> Self {
    self
  }
}
