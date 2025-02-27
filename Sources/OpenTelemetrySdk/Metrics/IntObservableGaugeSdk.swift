/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class IntObservableGaugeSdk: IntObserverMetric {
  public private(set) var observerHandles = [LabelSet: IntObservableGaugeHandle]()
  let name: String
  var callback: (IntObserverMetric) -> Void

  init(measurementName: String, callback: @escaping (IntObserverMetric) -> Void) {
    name = measurementName
    self.callback = callback
  }

  func observe(value: Int, labels: [String: String]) {
    observe(value: value, labelset: LabelSet(labels: labels))
  }

  func observe(value: Int, labelset: LabelSet) {
    var boundInstrument = observerHandles[labelset]
    if boundInstrument == nil {
      boundInstrument = IntObservableGaugeHandle()
      observerHandles[labelset] = boundInstrument
    }
    boundInstrument?.observe(value: value)
  }

  func invokeCallback() {
    callback(self)
  }
}
