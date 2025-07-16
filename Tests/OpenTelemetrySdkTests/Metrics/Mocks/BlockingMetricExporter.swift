//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetrySdk

class BlockingMetricExporter: MetricExporter {
  let cond = NSCondition()

  enum State {
    case waitToBlock
    case blocked
    case unblocked
  }

  var state: State = .waitToBlock

  let aggregrationTemporality: AggregationTemporality

  init(aggregationTemporality: AggregationTemporality) {
    aggregrationTemporality = aggregationTemporality
  }

  func export(metrics: [OpenTelemetrySdk.MetricData]) -> OpenTelemetrySdk.ExportResult {
    cond.lock()
    while state != .unblocked {
      state = .blocked
      // Some threads may wait for Blocked State.
      cond.broadcast()
      cond.wait()
    }
    cond.unlock()
    return .success
  }

  func waitUntilIsBlocked() {
    cond.lock()
    while state != .blocked {
      cond.wait()
    }
    cond.unlock()
  }

  func flush() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func shutdown() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregrationTemporality
  }
}

class WaitingMetricExporter: MetricExporter {
  var metricDataList = [MetricData]()
  let cond = NSCondition()
  let numberToWaitFor: Int
  var shutdownCalled = false
  var aggregationTemporality: AggregationTemporality = .delta
  init(numberToWaitFor: Int, aggregationTemporality: AggregationTemporality = .delta) {
    self.numberToWaitFor = numberToWaitFor
    self.aggregationTemporality = aggregationTemporality
  }

  func export(metrics: [OpenTelemetrySdk.MetricData]) -> OpenTelemetrySdk.ExportResult {
    cond.lock()
    metricDataList.append(contentsOf: metrics)
    cond.unlock()
    cond.broadcast()
    return .success
  }

  func waitForExport() -> [MetricData] {
    var ret: [MetricData]
    cond.lock()
    defer { cond.unlock() }
    while metricDataList.count < numberToWaitFor {
      cond.wait()
    }
    ret = metricDataList
    metricDataList.removeAll()
    return ret
  }

  func flush() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func shutdown() -> OpenTelemetrySdk.ExportResult {
    .success
  }

  func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    return aggregationTemporality
  }
}
