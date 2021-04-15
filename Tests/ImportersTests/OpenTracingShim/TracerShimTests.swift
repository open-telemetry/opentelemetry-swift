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

import OpenTelemetryApi
import OpenTelemetrySdk
import Opentracing
@testable import OpenTracingShim
import XCTest

class TracerShimTests: XCTestCase {
    var tracerShim = TracerShim(telemetryInfo: TelemetryInfo(tracer: OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "opentracingshim"),
                                                             baggageManager: OpenTelemetrySDK.instance.baggageManager,
                                                             propagators: OpenTelemetrySDK.instance.propagators))

    func testDefaultTracer() {
        _ = tracerShim.startSpan("one")
        XCTAssertNotNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testActiveSpan() {
        let otSpan = tracerShim.startSpan("one") as! SpanShim
        XCTAssertNotNil(OpenTelemetry.instance.contextProvider.activeSpan)
        otSpan.finish()
    }

    func testExtractNullContext() {
        let result = tracerShim.extract(withFormat: OTFormatTextMap, carrier: [String: String]())
        XCTAssertNil(result)
    }

    func testInjecttNullContext() {
        let otSpan = tracerShim.startSpan("one") as! SpanShim
        let map = [String: String]()
        _ = tracerShim.inject(otSpan.context(), format: OTFormatTextMap, carrier: map)
        XCTAssertEqual(map.count, 0)
    }
}
