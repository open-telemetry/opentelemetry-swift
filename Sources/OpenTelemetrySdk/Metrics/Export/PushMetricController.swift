// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
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
