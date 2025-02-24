/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class RawCounterMetricSdkBase<T>: RawCounterMetric {
  let bindUnbindLock = Lock()
  public private(set) var boundInstruments = [LabelSet: BoundRawCounterMetricSdkBase<T>]()
  let metricName: String

  init(name: String) {
    metricName = name
  }

  func record(sum: T, startDate: Date, endDate: Date, labels: [String: String]) {
    // noop
  }

  func record(sum: T, startDate: Date, endDate: Date, labelset: LabelSet) {
    // noop
  }

  func bind(labelset: LabelSet) -> BoundRawCounterMetric<T> {
    bind(labelset: labelset, isShortLived: false)
  }

  internal func bind(labelset: LabelSet, isShortLived: Bool) -> BoundRawCounterMetric<T> {
    var boundInstrument: BoundRawCounterMetricSdkBase<T>?
    bindUnbindLock.withLockVoid {
      boundInstrument = boundInstruments[labelset]

      if boundInstrument == nil {
        let status = isShortLived ? RecordStatus.updatePending : RecordStatus.bound
        boundInstrument = createMetric(recordStatus: status)
        boundInstruments[labelset] = boundInstrument
      }
    }

    boundInstrument!.statusLock.withLockVoid {
      switch boundInstrument!.status {
      case .noPendingUpdate:
        boundInstrument!.status = .updatePending
      case .candidateForRemoval:
        bindUnbindLock.withLockVoid {
          boundInstrument!.status = .updatePending
          if boundInstruments[labelset] == nil {
            boundInstruments[labelset] = boundInstrument!
          }
        }
      case .bound, .updatePending:
        break
      }
    }
    return boundInstrument!
  }

  func bind(labels: [String: String]) -> BoundRawCounterMetric<T> {
    return bind(labelset: LabelSet(labels: labels), isShortLived: false)
  }

  internal func unBind(labelSet: LabelSet) {
    bindUnbindLock.withLockVoid {
      if let boundInstrument = boundInstruments[labelSet] {
        boundInstrument.statusLock.withLockVoid {
          if boundInstrument.status == .candidateForRemoval {
            boundInstruments[labelSet] = nil
          }
        }
      }
    }
  }

  func createMetric(recordStatus: RecordStatus) -> BoundRawCounterMetricSdkBase<T> {
    // noop
    fatalError()
  }
}
