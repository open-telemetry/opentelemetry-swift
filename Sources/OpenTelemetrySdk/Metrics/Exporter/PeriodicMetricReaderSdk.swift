/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "PeriodicMetricReaderSdk")
public typealias StablePeriodicMetricReaderSdk = PeriodicMetricReaderSdk

public final class PeriodicMetricReaderSdk: MetricReader, @unchecked Sendable {
  let exporter: MetricExporter
  let exportInterval: TimeInterval
  let exportTimeout: TimeInterval
  let scheduleQueue = DispatchQueue(label: "org.opentelemetry.PeriodicMetricReaderSdk.scheduleQueue")
  // Uses `DispatchQoS.userInitiated` to match callers that sync-wait (forceFlush/shutdown) to avoid priority inversion.
  let exportQueue = DispatchQueue(label: "org.opentelemetry.PeriodicMetricReaderSdk.exportQueue",
                                  qos: .userInitiated)
  let exportOperationQueue: OperationQueue
  let scheduleTimer: DispatchSourceTimer
  let metricProduce: ReadWriteLocked<MetricProducer> = .init(initialValue: NoopMetricProducer())
  private let hasShutdown = Locked(initialValue: false)

  init(exporter: MetricExporter, exportInterval: TimeInterval = 60.0, exportTimeout: TimeInterval = 30.0) {
    self.exporter = exporter
    self.exportInterval = exportInterval
    if exportTimeout >= 0 {
      self.exportTimeout = exportTimeout
    } else {
      print("exportTimeout (\(exportTimeout)) < 0, fallback to default 30.")
      self.exportTimeout = 30
    }
    exportOperationQueue = OperationQueue()
    exportOperationQueue.name = "org.opentelemetry.PeriodicMetricReaderSdk.exportOperationQueue"
    exportOperationQueue.maxConcurrentOperationCount = 1
    scheduleTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(), queue: scheduleQueue)

    scheduleTimer.setEventHandler { [weak self] in
      autoreleasepool {
        self?.enqueueExport()
      }
    }
  }

  deinit {
    _ = shutdown()
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
    let result = Locked(initialValue: ExportResult.failure)
    let group = DispatchGroup()
    group.enter()
    exportQueue.async { [self] in
      result.locking { $0 = collectAndExport() }
      group.leave()
    }
    guard group.wait(timeout: .now() + exportTimeout) != .timedOut else {
      return .failure
    }
    return result.locking { $0 }
  }

  private func enqueueExport() {
    exportQueue.async { [weak self] in
      autoreleasepool {
        guard let self else {
          return
        }
        _ = self.collectAndExport()
      }
    }
  }

  private func collectAndExport() -> ExportResult {
    let metricData = metricProduce.protectedValue.collectAllMetrics()
    if metricData.isEmpty {
      return .success
    }
    return exportMetricsWithTimeout(metricData, timeout: exportTimeout)
  }

  private func exportMetricsWithTimeout(_ metrics: [MetricData], timeout: TimeInterval) -> ExportResult {
    let result = Locked(initialValue: ExportResult.failure)
    let exportOperation = BlockOperation { [exporter] in
      result.locking { $0 = exporter.export(metrics: metrics) }
    }
    let timeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    timeoutTimer.setEventHandler { exportOperation.cancel() }
    timeoutTimer.schedule(deadline: .now() + .milliseconds(Int(timeout.toMilliseconds)), leeway: .milliseconds(1))
    timeoutTimer.activate()
    exportOperationQueue.addOperation(exportOperation)
    exportOperationQueue.waitUntilAllOperationsAreFinished()
    timeoutTimer.cancel()
    if exportOperation.isCancelled {
      return .failure
    }
    return result.locking { $0 }
  }

  public func shutdown() -> ExportResult {
    let shouldShutdown = hasShutdown.locking { shutdown in
      guard !shutdown else {
        return false
      }
      shutdown = true
      return true
    }
    guard shouldShutdown else {
      return .success
    }

    scheduleTimer.suspend()
    if !scheduleTimer.isCancelled {
      scheduleTimer.cancel()
      scheduleTimer.resume()
    }
    // Wait for in-flight/queued exports before shutting down the exporter.
    let group = DispatchGroup()
    group.enter()
    exportQueue.async {
      group.leave()
    }
    let drainedInTime = group.wait(timeout: .now() + exportTimeout) != .timedOut
    let shutdownResult = exporter.shutdown()
    return drainedInTime && shutdownResult == .success ? .success : .failure
  }

  public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    exporter.getAggregationTemporality(for: instrument)
  }

  public func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
    return exporter.getDefaultAggregation(for: instrument)
  }
}
