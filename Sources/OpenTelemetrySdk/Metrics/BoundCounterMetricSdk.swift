/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class BoundCounterMetricSdk<T: SignedNumeric>: BoundCounterMetricSdkBase<T> {
  private var sumAggregator = CounterSumAggregator<T>()

  override init(recordStatus: RecordStatus) {
    super.init(recordStatus: recordStatus)
  }

  override func add(value: T) {
    sumAggregator.update(value: value)
  }

  override func getAggregator() -> CounterSumAggregator<T> {
    return sumAggregator
  }
}
