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

public class MeterProviderSdk: MeterProvider {
    private let lock = Lock()
    static public let defaultPushInterval: TimeInterval = 60

    var meterRegistry = [InstrumentationLibraryInfo: MeterSdk]()

    var meterSharedState : MeterSharedState
    var pushMetricController: PushMetricController!
    var defaultMeter: MeterSdk

    public convenience init() {
        self.init(metricProcessor: NoopMetricProcessor(),
                  metricExporter: NoopMetricExporter())
    }
    
    public init(metricProcessor: MetricProcessor,
                metricExporter: MetricExporter,
                metricPushInterval: TimeInterval = MeterProviderSdk.defaultPushInterval,
                resource: Resource = EnvVarResource.resource) {
        self.meterSharedState = MeterSharedState(metricProcessor:metricProcessor, metricPushInterval: metricPushInterval, resource: resource)

        defaultMeter = MeterSdk(meterSharedState: self.meterSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo())

        pushMetricController = PushMetricController(
            meterProvider: self,
            metricProcessor: metricProcessor,
            metricExporter: metricExporter,
            pushInterval: meterSharedState.metricPushInterval) {
            false
        }
    }



    public func get(instrumentationName: String, instrumentationVersion: String? = nil) -> Meter {
        if instrumentationName.isEmpty {
            return defaultMeter
        }

        lock.lock()
        defer {
            lock.unlock()
        }
        let instrumentationLibraryInfo  = InstrumentationLibraryInfo(name: instrumentationName, version: instrumentationVersion)
        var meter: MeterSdk! = meterRegistry[instrumentationLibraryInfo]
        if meter == nil {
            meter = MeterSdk(meterSharedState: self.meterSharedState, instrumentationLibraryInfo: instrumentationLibraryInfo)
            meterRegistry[instrumentationLibraryInfo] = meter!
        }
        return meter!
    }

    func getMeters() -> [InstrumentationLibraryInfo: MeterSdk] {
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
