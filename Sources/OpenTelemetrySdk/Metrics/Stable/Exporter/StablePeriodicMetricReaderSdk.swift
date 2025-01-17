/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
public class StablePeriodicMetricReaderSdk: StableMetricReader {

    let exporter: StableMetricExporter
    let exportInterval: TimeInterval
    let scheduleQueue = DispatchQueue(label: "org.opentelemetry.StablePeriodicMetricReaderSdk.scheduleQueue")
    let scheduleTimer: DispatchSourceTimer
    var metricProduce: MetricProducer = NoopMetricProducer()

    init(exporter: StableMetricExporter, exportInterval: TimeInterval = 60.0) {
        self.exporter = exporter
        self.exportInterval = exportInterval
        scheduleTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(), queue: scheduleQueue)

        scheduleTimer.setEventHandler { [weak self] in
            autoreleasepool {
                guard let self = self else {
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
            metricProduce = newProducer
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
        let metricData = metricProduce.collectAllMetrics()
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
