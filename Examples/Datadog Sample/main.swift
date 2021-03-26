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

import DatadogExporter
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

let clientKey = ""
let apikey = ""

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

let instrumentationLibraryName = "DatadogExporter"
let instrumentationLibraryVersion = "semver:0.1.0"
var instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)

var tracer: TracerSdk
tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk

let exporterConfiguration = ExporterConfiguration(
    serviceName: "Opentelemetry exporter Example",
    resource: "Opentelemetry exporter",
    applicationName: "SimpleExample",
    applicationVersion: "1.0.0",
    environment: "test",
    clientToken: clientKey,
    apiKey: apikey,
    endpoint: Endpoint.us,
    uploadCondition: { true },
    performancePreset: .instantDataDelivery,
    hostName: Host.current().localizedName
)

let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

testTraces()
testMetrics()

sleep(10)

func testTraces() {
    let spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
    OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)

    simpleSpan()
    childSpan()
    spanProcessor.shutdown()
}

func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    span.addEvent(name: "My event", attributes: ["message": AttributeValue.string("test message")])
    span.end()
}

func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    OpenTelemetryContext.setActiveSpan(span)
    let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    childSpan.end()
    span.end()
}

func testMetrics() {
    let processor = UngroupedBatcher()

    let meterProvider = MeterSdkProvider(metricProcessor: processor, metricExporter: datadogExporter, metricPushInterval: 0.1)

    let meter = meterProvider.get(instrumentationName: "MyMeter")

    let testCounter = meter.createIntCounter(name: "MyCounter")
    let testMeasure = meter.createIntMeasure(name: "MyMeasure")

    let labels1 = ["dim1": "value1"]
    let labels2 = ["dim1": "value2"]

    _ = meter.createIntObserver(name: "MyObservation") { observer in
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let _: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        observer.observe(value: Int(taskInfo.resident_size), labels: labels2)
    }

    var counter = 0
    while counter < 3000 {
        testCounter.add(value: 100, labelset: meter.getLabelSet(labels: labels1))

        testMeasure.record(value: 100, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 500, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 5, labelset: meter.getLabelSet(labels: labels1))
        testMeasure.record(value: 750, labelset: meter.getLabelSet(labels: labels1))
        counter += 1
        sleep(1)
    }
}
