/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "StableMeterProviderSdk")
public class MeterProviderSdk: MeterProvider {
    private let lock = Lock()
    public static let defaultPushInterval: TimeInterval = 60

    var meterRegistry = [InstrumentationLibraryInfo: MeterSdk]()

    var meterSharedState: MeterSharedState
    var pushMetricController: PushMetricController!
    var defaultMeter: MeterSdk

    public convenience init() {
        self.init(metricProcessor: NoopMetricProcessor(),
                  metricExporter: NoopMetricExporter())
    }

    public init(metricProcessor: MetricProcessor,
                metricExporter: MetricExporter,
                metricPushInterval: TimeInterval = MeterProviderSdk.defaultPushInterval,
                resource: Resource = EnvVarResource.resource)
    {
        meterSharedState = MeterSharedState(metricProcessor: metricProcessor, metricPushInterval: metricPushInterval, metricExporter: metricExporter, resource: resource)

        defaultMeter = MeterSdk(meterSharedState: meterSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo())

        pushMetricController = PushMetricController(
            meterProvider: self,
            meterSharedState: meterSharedState
        ) {
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
        let instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationName, version: instrumentationVersion)
        var meter: MeterSdk! = meterRegistry[instrumentationLibraryInfo]
        if meter == nil {
            meter = MeterSdk(meterSharedState: meterSharedState, instrumentationLibraryInfo: instrumentationLibraryInfo)
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

    public func setMetricProcessor(_ metricProcessor: MetricProcessor) {
        pushMetricController.pushMetricQueue.sync {
            meterSharedState.metricProcessor = metricProcessor
        }
    }

    public func addMetricExporter(_ metricExporter: MetricExporter) {
        pushMetricController.pushMetricQueue.sync {
            meterSharedState.addMetricExporter(metricExporter: metricExporter)
        }
    }

    public func setMetricPushInterval(_ interval: TimeInterval) {
        pushMetricController.pushMetricQueue.sync {
            meterSharedState.metricPushInterval = interval
        }
    }

    public func setResource(_ resource: Resource) {
        pushMetricController.pushMetricQueue.sync {
            meterSharedState.resource = resource
        }
    }

    private static func createLibraryResourceLabels(name: String, version: String) -> [String: String] {
        var labels = ["name": name]
        if !version.isEmpty {
            labels["version"] = version
        }
        return labels
    }
}
