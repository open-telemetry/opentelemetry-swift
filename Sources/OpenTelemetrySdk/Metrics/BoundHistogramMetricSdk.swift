/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

internal class BoundHistogramMetricSdk<T: SignedNumeric & Comparable>: BoundHistogramMetricSdkBase<T> {
  private var histogramAggregator: HistogramAggregator<T>

  override init(explicitBoundaries: [T]? = nil) {
    histogramAggregator = try! HistogramAggregator(explicitBoundaries: explicitBoundaries)
    super.init(explicitBoundaries: explicitBoundaries)
  }

  override func record(value: T) {
    histogramAggregator.update(value: value)
  }

  override func getAggregator() -> HistogramAggregator<T> {
    return histogramAggregator
  }
}
