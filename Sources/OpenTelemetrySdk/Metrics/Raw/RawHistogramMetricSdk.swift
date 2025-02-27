/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

internal class RawHistogramMetricSdk<T: SignedNumeric & Comparable>: RawHistogramMetricSdkBase<T> {
  override init(name: String) {
    super.init(name: name)
  }

  override func record(explicitBoundaries: [T], counts: [Int], startDate: Date, endDate: Date, count: Int, sum: T, labels: [String: String]) {
    bind(labelset: LabelSet(labels: labels), isShortLived: true).record(explicitBoundaries: explicitBoundaries, counts: counts, startDate: startDate, endDate: endDate, count: count, sum: sum)
  }

  override func record(explicitBoundaries: [T], counts: [Int], startDate: Date, endDate: Date, count: Int, sum: T, labelset: LabelSet) {
    bind(labelset: labelset, isShortLived: true).record(explicitBoundaries: explicitBoundaries, counts: counts, startDate: startDate, endDate: endDate, count: count, sum: sum)
  }

  override func createMetric(recordStatus: RecordStatus) -> BoundRawHistogramMetricSdkBase<T> {
    return BoundRawHistogramMetricSdk<T>(recordStatus: recordStatus)
  }
}
