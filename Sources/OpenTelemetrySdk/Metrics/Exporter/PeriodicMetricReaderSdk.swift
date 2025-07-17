/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "PeriodicMetricReaderSdk")
public typealias StablePeriodicMetricReaderSdk = PeriodicMetricReaderSdk

public class PeriodicMetricReaderSdk: MetricReader {
  let exporter: MetricExporter
  let exportInterval: TimeInterval
  let scheduleQueue = DispatchQueue(label: "org.opentelemetry.StablePeriodicMetricReaderSdk.scheduleQueue")
  let scheduleTimer: DispatchSourceTimer
  let metricProduce: ReadWriteLocked<MetricProducer> = .init(initialValue: NoopMetricProducer())

  init(exporter: MetricExporter, exportInterval: TimeInterval = 60.0) {
    self.exporter = exporter
    self.exportInterval = exportInterval
    scheduleTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(), queue: scheduleQueue)

    scheduleTimer.setEventHandler { [weak self] in
      autoreleasepool {
        guard let self else {
          return
        }
        _ = self.doRun()
      }
    }
  }

  deinit {
    _ = shutdown()
    scheduleTimer.activate()
  }

  public func register(registration: CollectionRegistration) {
    if let newProducer = registration as? MetricProducer {
      metricProduce.protectedValue = newProducer
      start()
    } else {
      // todo: error : unrecognized CollectionRegistration
    }
  }

  func start() {
    scheduleTimer.schedule(deadline: .now() + exportInterval, repeating: exportInterval)
    scheduleTimer.activate()
  }

  public func forceFlush() -> ExportResult {
    doRun()
  }

  private func doRun() -> ExportResult {
    let metricData = metricProduce.protectedValue.collectAllMetrics()
    if metricData.isEmpty {
      return .success
    }
    return exporter.export(metrics: metricData)
  }

  public func shutdown() -> ExportResult {
    scheduleTimer.suspend()
    if !scheduleTimer.isCancelled {
      scheduleTimer.cancel()
      scheduleTimer.resume()
    }
    return exporter.shutdown()
  }

  public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    exporter.getAggregationTemporality(for: instrument)
  }

  public func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
    return exporter.getDefaultAggregation(for: instrument)
  }
}
