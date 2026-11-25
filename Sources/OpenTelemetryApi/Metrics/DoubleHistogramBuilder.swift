/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleHistogramBuilder: AnyObject {
  associatedtype AnyLongHistogramBuilder: LongHistogramBuilder
  associatedtype AnyDoubleHistogram: DoubleHistogram
  func ofLongs() -> AnyLongHistogramBuilder

  /// Sets explicit bucket boundaries advice for the histogram.
  /// This is a hint to the SDK about the recommended bucket boundaries.
  /// The SDK may ignore this advice if a View is configured for this instrument.
  /// - Parameter boundaries: Array of bucket boundaries in ascending order
  /// - Returns: Self for method chaining
  func setExplicitBucketBoundariesAdvice(_ boundaries: [Double]) -> Self

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

  func build() -> AnyDoubleHistogram
}

/// Default implementations that ignore the value, so conforming types written before these
/// requirements existed keep compiling. Implementations that export metrics should override them.
public extension DoubleHistogramBuilder {
  func setUnit(_ unit: String) -> Self {
    self
  }

  func setDescription(_ description: String) -> Self {
    self
  }
}
