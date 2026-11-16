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

  func build() -> AnyDoubleHistogram
}
