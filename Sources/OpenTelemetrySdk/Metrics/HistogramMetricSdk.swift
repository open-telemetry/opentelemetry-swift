/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class HistogramMetricSdk<T: SignedNumeric & Comparable>: HistogramMetric {
  public private(set) var boundInstruments = [LabelSet: BoundHistogramMetricSdkBase<T>]()
  let metricName: String
  let explicitBoundaries: [T]?
  let bindUnbindLock = Lock()

  init(name: String, explicitBoundaries: [T]? = nil) {
    metricName = name
    self.explicitBoundaries = explicitBoundaries
  }

  func bind(labelset: LabelSet) -> BoundHistogramMetric<T> {
    bindUnbindLock.withLock {
      var boundInstrument = boundInstruments[labelset]
      if boundInstrument == nil {
        boundInstrument = createMetric()
        boundInstruments[labelset] = boundInstrument!
      }

      return boundInstrument!
    }
  }

  func bind(labels: [String: String]) -> BoundHistogramMetric<T> {
    return bind(labelset: LabelSet(labels: labels))
  }

  func createMetric() -> BoundHistogramMetricSdkBase<T> {
    return BoundHistogramMetricSdk<T>(explicitBoundaries: explicitBoundaries)
  }
}
