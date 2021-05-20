/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation

class PushMetricController {
    var meterSharedState: MeterSharedState
    var meterProvider: MeterProviderSdk

    let pushMetricQueue = DispatchQueue(label: "org.opentelemetry.PushMetricController.pushMetricQueue")

    init(meterProvider: MeterProviderSdk, meterSharedState: MeterSharedState, shouldCancel: (() -> Bool)? = nil) {
        self.meterProvider = meterProvider
        self.meterSharedState = meterSharedState
        pushMetricQueue.asyncAfter(deadline: .now() + meterSharedState.metricPushInterval) { [weak self] in
            guard let self = self else {
                return
            }
            while !(shouldCancel?() ?? false) {
                autoreleasepool {
                    let start = Date()
                    let values = self.meterProvider.getMeters().values
                    values.forEach {
                        $0.collect()
                    }

                    let metricToExport = self.meterSharedState.metricProcessor.finishCollectionCycle()

                    _ = meterSharedState.metricExporter.export(metrics: metricToExport, shouldCancel: shouldCancel)
                    let timeInterval = Date().timeIntervalSince(start)
                    let remainingWait = meterSharedState.metricPushInterval - timeInterval
                    if remainingWait > 0 {
                        usleep(UInt32(remainingWait * 1000000))
                    }
                }
            }
        }
    }
}
