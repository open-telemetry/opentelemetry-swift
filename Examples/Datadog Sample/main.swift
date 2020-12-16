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
import OpenTelemetrySdk
import OpenTelemetryApi


let clientKey = ""

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

let instrumentationLibraryName = "DatadogExporter"
let instrumentationLibraryVersion = "semver:0.1.0"
var instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)

var tracer: TracerSdk
tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk

func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    span.addEvent(name: "My event", attributes: ["message": AttributeValue.string("test message")])
    span.end()
}

func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    tracer.setActive(span)
    let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
    childSpan.setAttribute(key: sampleKey, value: sampleValue)
    childSpan.end()
    span.end()
}

let exporterConfiguration = ExporterConfiguration(
    serviceName: "Otel exporter Example",
    resource: "OTel exporter",
    applicationName: "SimpleExample",
    applicationVersion: "0.0.1",
    environment: "test",
    clientToken: clientKey,
    endpoint: Endpoint.us,
    uploadCondition: { true },
    performancePreset: .instantDataDelivery
)

let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

var spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)

simpleSpan()
childSpan()
spanProcessor.shutdown()

sleep(10)
