/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS)

import DatadogExporter
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

let apikeyOrClientToken = ""

let resourceKey = "resource.name"
let resourceValue = "The resource"

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

let instrumentationScopeName = "DatadogExporter"
let instrumentationScopeVersion = "semver:0.1.0"

var tracer: Tracer
tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion)

let hostName = Host.current().localizedName

let exporterConfiguration = ExporterConfiguration(
    serviceName: "Opentelemetry exporter Example",
    resource: "Opentelemetry exporter",
    applicationName: "SwiftDatadogSample",
    applicationVersion: "1.0.0",
    environment: "test",
    apiKey: apikeyOrClientToken,
    endpoint: Endpoint.us1,
    uploadCondition: { true },
    performancePreset: .instantDataDelivery,
    hostName: hostName
)

let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

testTraces()
testMetrics()

sleep(10)

func testTraces() {
    let spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
    
    OpenTelemetry.registerTracerProvider(tracerProvider:
        TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .build()
    )
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk

    simpleSpan()
    childSpan()
    spanProcessor.shutdown()
}

func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: resourceKey, value: resourceValue)
    span.addEvent(name: "My event", attributes: ["message": AttributeValue.string("test message"),
                                                 "newKey": AttributeValue.string("New Value")])
    span.end()
}

func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).setActive(true).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    childSpan.end()
    span.end()
}

func testMetrics() {
    let processor = MetricProcessorSdk()

    let meterProvider = MeterProviderSdk(metricProcessor: processor, metricExporter: datadogExporter, metricPushInterval: 0.1)
    OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)

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

#endif
