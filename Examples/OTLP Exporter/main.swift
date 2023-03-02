/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS)

import Foundation
import GRPC
import NIO
import NIOSSL
import OpenTelemetryApi
import OpenTelemetryProtocolExporter
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration
import StdoutExporter
import ZipkinExporter

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

var resources = DefaultResources().get()

let instrumentationScopeName = "OTLPExporter"
let instrumentationScopeVersion = "semver:0.1.0"

let configuration = ClientConnection.Configuration.default(
    target: .hostAndPort("localhost", 4317),
    eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1)
)
let client = ClientConnection(configuration: configuration)

let otlpTraceExporter = OtlpTraceExporter(channel: client)
let stdoutExporter = StdoutExporter()
let spanExporter = MultiSpanExporter(spanExporters: [otlpTraceExporter, stdoutExporter])

let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
OpenTelemetry.registerTracerProvider(tracerProvider:
    TracerProviderBuilder()
        .add(spanProcessor: spanProcessor)
        .build()
)

let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion)


if #available(macOS 10.14, *), #available(iOS 12.0, *) {
    let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
    tracerProviderSDK?.addSpanProcessor(SignPostIntegration())
}

func createSpans() {
    let parentSpan1 = tracer.spanBuilder(spanName: "Main").setSpanKind(spanKind: .client).startSpan()
    parentSpan1.setAttribute(key: sampleKey, value: sampleValue)
    OpenTelemetry.instance.contextProvider.setActiveSpan(parentSpan1)
    for _ in 1...3 {
        doWork()
    }
    Thread.sleep(forTimeInterval: 0.5)

    let parentSpan2 = tracer.spanBuilder(spanName: "Another").setSpanKind(spanKind: .client).setActive(true).startSpan()
    parentSpan2.setAttribute(key: sampleKey, value: sampleValue)
    // do more Work
    for _ in 1...3 {
        doWork()
    }
    Thread.sleep(forTimeInterval: 0.5)

    parentSpan2.end()
    parentSpan1.end()
}

func doWork() {
    let childSpan = tracer.spanBuilder(spanName: "doWork").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: Double.random(in: 0 ..< 10) / 100)
    childSpan.end()
}

// Create a Parent span (Main) and do some Work (child Spans). Repeat for another Span.
createSpans()

// Metrics
let otlpMetricExporter = OtlpMetricExporter(channel: client)
let processor = MetricProcessorSdk()
let meterProvider = MeterProviderSdk(metricProcessor: processor, metricExporter: otlpMetricExporter, metricPushInterval: 0.1)

OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)


var meter = meterProvider.get(instrumentationName: "otlp_example_meter'")
var exampleCounter = meter.createIntCounter(name: "otlp_example_counter")
var exampleMeasure = meter.createIntMeasure(name: "otlp_example_measure")
var exampleObserver = meter.createIntObserver(name: "otlp_example_observation") { observer in
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let _: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    labels1 = ["dim1": "value1"]
    observer.observe(value: Int(taskInfo.resident_size), labels: labels1)
}

var labels1 = ["dim1": "value1"]
for _ in 1...3000 {
    exampleCounter.add(value: 1, labelset: meter.getLabelSet(labels: labels1))
    exampleMeasure.record(value: 100, labelset: meter.getLabelSet(labels: labels1))
    exampleMeasure.record(value: 500, labelset: meter.getLabelSet(labels: labels1))
    exampleMeasure.record(value: 5, labelset: meter.getLabelSet(labels: labels1))
    exampleMeasure.record(value: 750, labelset: meter.getLabelSet(labels: labels1))
    sleep(1)
}

#endif
