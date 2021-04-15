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

Logger.printHeader()

OpenTelemetry.registerTracerProvider(tracerProvider: LoggingTracerProvider())

var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ConsoleApp", instrumentationVersion: "semver:1.0.0")


let span1 = tracer.spanBuilder(spanName: "Main (span1)").startSpan()
OpenTelemetry.instance.contextProvider.setActiveSpan(span1)
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
