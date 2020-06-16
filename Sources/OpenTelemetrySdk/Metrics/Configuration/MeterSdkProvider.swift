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

public class MeterSdkProvider: MeterProvider {
    private let lock = Lock()
    private let defaultPushInterval: TimeInterval = 60

    var meterRegistry = [MeterRegistryKey: MeterSdk]()

    let metricProcessor: MetricProcessor
    let metricExporter: MetricExporter
    var pushMetricController: PushMetricController!
    var defaultMeter: MeterSdk

    public convenience init() {
        self.init(meterSharedState: MeterSharedState())
    }

    public init(meterSharedState: MeterSharedState) {
        metricProcessor = meterSharedState.metricProcessor ?? NoopMetricProcessor()
        metricExporter = meterSharedState.metricExporter ?? NoopMetricExporter()

        defaultMeter = MeterSdk(meterName: "", metricProcessor: metricProcessor)

        let defaultPushInterval = self.defaultPushInterval
        pushMetricController = PushMetricController(
            meterProvider: self,
            metricProcessor: metricProcessor,
            metricExporter: metricExporter,
            pushInterval: meterSharedState.metricPushInterval ?? defaultPushInterval) {
            false
        }
    }

    public static func create(configure: (MeterSharedState) -> Void) -> MeterSdkProvider {
        let builder = MeterSharedState()
        configure(builder)

        return MeterSdkProvider(meterSharedState: builder)
    }

    public func get(instrumentationName: String, instrumentationVersion: String? = nil) -> Meter {
        if instrumentationName.isEmpty {
            return defaultMeter
        }

        lock.lock()
        defer {
            lock.unlock()
        }
        let key = MeterRegistryKey(name: instrumentationName, version: instrumentationVersion)
        var meter: MeterSdk! = meterRegistry[key]
        if meter == nil {
            meter = MeterSdk(meterName: instrumentationName, metricProcessor: metricProcessor)
            meterRegistry[key] = meter!
        }
        return meter!
    }

    func getMeters() -> [MeterRegistryKey: MeterSdk] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return meterRegistry
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
