/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class RawCounterMetricSdk<T: SignedNumeric & Comparable>: RawCounterMetricSdkBase<T> {
  override init(name: String) {
    super.init(name: name)
  }

  override func record(sum: T, startDate: Date, endDate: Date, labels: [String: String]) {
    bind(labelset: LabelSet(labels: labels), isShortLived: true).record(sum: sum, startDate: startDate, endDate: endDate)
  }

  override func record(sum: T, startDate: Date, endDate: Date, labelset: LabelSet) {
    bind(labelset: labelset, isShortLived: true).record(sum: sum, startDate: startDate, endDate: endDate)
  }

  override func createMetric(recordStatus: RecordStatus) -> BoundRawCounterMetricSdkBase<T> {
    return BoundRawCounterMetricSdk<T>(recordStatus: recordStatus)
  }
}
