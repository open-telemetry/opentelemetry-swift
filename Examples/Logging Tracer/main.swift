/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

Logger.printHeader()

OpenTelemetry.registerTracerProvider(tracerProvider: LoggingTracerProvider())

var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ConsoleApp", instrumentationVersion: "semver:1.0.0")


let span1 = tracer.spanBuilder(spanName: "Main (span1)").startSpan()
OpenTelemetry.instance.contextProvider.withActiveSpan(span1) {
    let semaphore = DispatchSemaphore(value: 0)

    let state = OpenTelemetry.instance.contextProvider.getCurrentState()
    DispatchQueue.global().async {
        // Note: Restoring state here isn't necessary for the activity based context manager, activities are tracked across DispatchQueues
        state.withRestoredState {
            let span2 = tracer.spanBuilder(spanName: "Main (span2)").startSpan()
            OpenTelemetry.instance.contextProvider.withActiveSpan(span2) {
                OpenTelemetry.instance.contextProvider.activeSpan?.setAttribute(key: "myAttribute", value: "myValue")
                sleep(1)
            }

            span2.end()
            semaphore.signal()
        }
    }
    span1.end()

    semaphore.wait()
}


