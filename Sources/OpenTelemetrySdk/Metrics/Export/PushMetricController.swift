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
    public private(set) var pushInterval: TimeInterval
    var metricExporter: MetricExporter
    var metricProcessor: MetricProcessor
    var meters: [MeterRegistryKey: MeterSdk]

    let pushMetricQueue = DispatchQueue(label: "org.opentelemetry.PushMetricController.pushMetricQueue")

    init(meters: [MeterRegistryKey: MeterSdk], metricProcessor: MetricProcessor, metricExporter: MetricExporter, pushInterval: TimeInterval, shouldCancel: (() -> Bool)? = nil) {
        self.meters = meters
        self.metricProcessor = metricProcessor
        self.metricExporter = metricExporter
        self.pushInterval = pushInterval
        pushMetricQueue.asyncAfter(deadline: .now() + pushInterval) {
            while !(shouldCancel?() ?? false) {
                let start = DispatchTime.now()
                for index in meters.values.indices {
                    self.meters.values[index].collect()
                }

                let metricToExport = self.metricProcessor.finishCollectionCycle()

                _ = metricExporter.export(metrics: metricToExport, shouldCancel: shouldCancel)
                let timeInterval = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1000000000
                let remainingWait = pushInterval - timeInterval
                if remainingWait > 0 {
                    usleep(UInt32(remainingWait * 1000000))
                }
            }
        }
    }
}
