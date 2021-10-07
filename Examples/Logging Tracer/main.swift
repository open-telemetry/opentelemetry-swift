/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

Logger.printHeader()

OpenTelemetry.registerTracerProvider(tracerProvider: LoggingTracerProvider())

var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ConsoleApp", instrumentationVersion: "semver:1.0.0")


let span1 = tracer.spanBuilder(spanName: "Main (span1)").setActive(true).startSpan()
let semaphore = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    let span2 = tracer.spanBuilder(spanName: "Main (span2)").startSpan()
    OpenTelemetry.instance.contextProvider.setActiveSpan(span2)
    OpenTelemetry.instance.contextProvider.activeSpan?.setAttribute(key: "myAttribute", value: "myValue")
    sleep(1)
    semaphore.signal()
    span2.end()
}
span1.end()

semaphore.wait()
