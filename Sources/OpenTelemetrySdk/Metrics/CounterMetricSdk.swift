/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class CounterMetricSdk<T: SignedNumeric>: CounterMetricSdkBase<T> {
  override init(name: String) {
    super.init(name: name)
  }

  override func add(value: T, labelset: LabelSet) {
    bind(labelset: labelset, isShortLived: true).add(value: value)
  }

  override func add(value: T, labels: [String: String]) {
    bind(labelset: LabelSetSdk(labels: labels), isShortLived: true).add(value: value)
  }

  override func createMetric(recordStatus: RecordStatus) -> BoundCounterMetricSdkBase<T> {
    return BoundCounterMetricSdk<T>(recordStatus: recordStatus)
  }
}
