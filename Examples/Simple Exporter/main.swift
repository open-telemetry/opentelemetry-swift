/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import JaegerExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
import StdoutExporter
import ZipkinExporter
import SignPostIntegration

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

let resources = DefaultResources().get()

let instrumentationLibraryName = "SimpleExporter"
let instrumentationLibraryVersion = "semver:0.1.0"
var instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)

var tracer: TracerSdk
tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk

func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.5)
    span.end()
}

func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).setActive(true).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.2)
    let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    Thread.sleep(forTimeInterval: 0.5)
    childSpan.end()
    span.end()
}

let jaegerCollectorAdress = "localhost"
let jaegerExporter = JaegerSpanExporter(serviceName: "SimpleExporter", collectorAddress: jaegerCollectorAdress)
let stdoutExporter = StdoutExporter()

// let zipkinExporterOptions = ZipkinTraceExporterOptions()
// let zipkinExporter = ZipkinTraceExporter(options: zipkinExporterOptions)

let spanExporter = MultiSpanExporter(spanExporters: [jaegerExporter, stdoutExporter /* , zipkinExporter */ ])

let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)

if #available(macOS 10.14, *) {
    OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(SignPostIntegration())
}


simpleSpan()
sleep(1)
childSpan()
sleep(1)
