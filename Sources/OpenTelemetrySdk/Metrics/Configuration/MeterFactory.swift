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
import OpenTelemetryApi

public class MeterFactory: MeterFactoryBase {
    fileprivate let lock = Lock()

    var meterRegistry = [MeterRegistryKey: MeterSdk]()

    let metricProcessor: MetricProcessor
    let metricExporter: MetricExporter
    let pushMetricController: PushMetricController
    let defaultPushInterval: TimeInterval = 60
    var defaultMeter: MeterSdk

    init(meterBuilder: MeterBuilder) {
        metricProcessor = meterBuilder.metricProcessor ?? NoopMetricProcessor()
        metricExporter = meterBuilder.metricExporter ?? NoopMetricExporter()

        defaultMeter = MeterSdk(meterName: "", metricProcessor: metricProcessor)
        meterRegistry[MeterRegistryKey(name: "", version: "")] = defaultMeter

        let defaultPushInterval = self.defaultPushInterval
        pushMetricController = PushMetricController(
            meters: meterRegistry,
            metricProcessor: metricProcessor,
            metricExporter: metricExporter,
            pushInterval: meterBuilder.metricPushInterval ?? defaultPushInterval) {
            false
        }

        super.init()
    }

    public static func create(configure: (MeterBuilder) -> Void) -> MeterFactory {
        let builder = MeterBuilder()
        configure(builder)

        return MeterFactory(meterBuilder: builder)
    }

    public func getMeter(name: String, version: String? = nil) -> Meter {
        if name.isEmpty {
            return defaultMeter
        }

        lock.lock()
        defer {
            lock.unlock()
        }
        let key = MeterRegistryKey(name: name, version: version)
        var meter: MeterSdk! = meterRegistry[key]
        if meter == nil {
            meter = MeterSdk(meterName: name, metricProcessor: metricProcessor)
            defaultMeter = meter!
            meterRegistry[key] = meter!
        }
        return meter!
    }

    private static func createLibraryResourceLabels(name: String, version: String) -> [String: String] {
        var labels = ["name": name]
        if !version.isEmpty {
            labels["version"] = version
        }
        return labels
    }
}

struct MeterRegistryKey: Hashable {
    var name: String
    var version: String?
}
