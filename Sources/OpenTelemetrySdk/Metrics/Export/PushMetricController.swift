/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation

class PushMetricController {
    var meterSharedState: MeterSharedState
    weak var meterProvider: MeterProviderSdk?

    let pushMetricQueue = DispatchQueue(label: "org.opentelemetry.PushMetricController.pushMetricQueue")
    let metricPushTimer: DispatchSourceTimer

    init(meterProvider: MeterProviderSdk, meterSharedState: MeterSharedState, shouldCancel: (() -> Bool)? = nil) {
        self.meterProvider = meterProvider
        self.meterSharedState = meterSharedState
        metricPushTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(), queue: pushMetricQueue)
        metricPushTimer.setEventHandler { [weak self] in
            autoreleasepool {
                guard let self = self,
                      let meterProvider = self.meterProvider else {
                    return
                }
                if shouldCancel?() ?? false {
                    self.metricPushTimer.cancel()
                    return
                }
                let values = meterProvider.getMeters().values
                values.forEach {
                    $0.collect()
                }

                let metricToExport = self.meterSharedState.metricProcessor.finishCollectionCycle()

                _ = meterSharedState.metricExporter.export(metrics: metricToExport, shouldCancel: shouldCancel)
            }
        }

        metricPushTimer.schedule(deadline: .now() + meterSharedState.metricPushInterval, repeating: meterSharedState.metricPushInterval)
        metricPushTimer.activate()
    }

    deinit {
        metricPushTimer.suspend() // suspending the timer prior to checking `isCancelled()` prevents a race condition between the check and actually calling `cancel()`
        if !metricPushTimer.isCancelled {
            metricPushTimer.cancel()
            metricPushTimer.resume()
        }
    }
}
