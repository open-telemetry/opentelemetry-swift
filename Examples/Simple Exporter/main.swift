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
import JaegerExporter
import OpenTelemetrySdk
import StdoutExporter

let sampleKey = "sampleKey"
let sampleValue = "sampleValue"

let instrumentationLibraryName = "SimpleExporter"
let instrumentationLibraryVersion = "semver:0.1.0"
var instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)

var tracer: TracerSdk
tracer = OpenTelemetrySDK.instance.tracerFactory.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk

func simpleSpan() {
    let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    span.end()
}

func childSpan() {
    let span = tracer.spanBuilder(spanName: "parentSpan").setSpanKind(spanKind: .client).startSpan()
    span.setAttribute(key: sampleKey, value: sampleValue)
    do {
        var scope = tracer.withSpan(span)
        let childSpan = tracer.spanBuilder(spanName: "childSpan").setSpanKind(spanKind: .client).startSpan()
        do {
            var childScope = tracer.withSpan(childSpan)
            childSpan.setAttribute(key: sampleKey, value: sampleValue)
            childScope.close()
        }
        childSpan.end()
        scope.close()
    }
    span.end()
}

let jaegerCollectorAdress = "localhost"
let jaegerExporter = JaegerSpanExporter(serviceName: "SimpleExporter", collectorAddress: jaegerCollectorAdress)
let stdoutExporter = StdoutExporter()

let spanExporter = MultiSpanExporter(spanExporters: [jaegerExporter, stdoutExporter])

let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
OpenTelemetrySDK.instance.tracerFactory.addSpanProcessor(spanProcessor)

simpleSpan()
sleep(1)
childSpan()
sleep(1)
