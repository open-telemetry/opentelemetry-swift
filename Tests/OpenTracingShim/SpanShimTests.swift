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
@testable import OpenTracingShim
import XCTest

class SpanShimTests: XCTestCase {
    let tracerSdkProvider = TracerSdkProvider()
    var tracer: Tracer!
    var telemetryInfo: TelemetryInfo!
    var span: Span!
    var tracerShim: TracerShim!

    let spanName = "Span"

    override func setUp() {
        tracer = tracerSdkProvider.get(instrumentationName: "SpanShimTest")
        telemetryInfo = TelemetryInfo(tracer: tracer, contextManager: OpenTelemetrySDK.instance.contextManager, propagators: OpenTelemetrySDK.instance.propagators)
        span = tracer.spanBuilder(spanName: spanName).startSpan()
        tracerShim = TracerShim(telemetryInfo: telemetryInfo)
    }

    override func tearDown() {
        span.end()
    }

    func testContextSimple() {
        let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
        let contextShim = spanShim.context() as! SpanContextShim
        XCTAssertEqual(contextShim.context, span.context)
    }

    func testBaggage() {
        let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)

        _ = spanShim.setBaggageItem("key1", value: "value1")
        _ = spanShim.setBaggageItem("key2", value: "value2")
        XCTAssertEqual(spanShim.getBaggageItem("key1"), "value1")
        XCTAssertEqual(spanShim.getBaggageItem("key2"), "value2")

        let contextShim = spanShim.context() as! SpanContextShim
        let baggageDict = TestUtils.contextBaggageToDictionary(context: contextShim)
        XCTAssertEqual(baggageDict.count, 2)
        XCTAssertEqual(baggageDict["key1"], "value1")
        XCTAssertEqual(baggageDict["key2"], "value2")
    }

    func testBaggageReplacement() {
        let spanShim = SpanShim(telemetryInfo: telemetryInfo, span: span)
        let contextShim1 = spanShim.context() as! SpanContextShim

        _ = spanShim.setBaggageItem("key1", value: "value1")
        let contextShim2 = spanShim.context() as! SpanContextShim

        XCTAssertNotEqual(contextShim1, contextShim2)
        XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: contextShim1).count, 0)
        XCTAssertNotEqual(TestUtils.contextBaggageToDictionary(context: contextShim2).count, 0)
    }

    func testBaggageDifferentShimObjs() {
        let spanShim1 = SpanShim(telemetryInfo: telemetryInfo, span: span)
        _ = spanShim1.setBaggageItem("key1", value: "value1")

        // Baggage should be synchronized among different SpanShim objects referring to the same Span.

        let spanShim2 = SpanShim(telemetryInfo: telemetryInfo, span: span)
        _ = spanShim2.setBaggageItem("key1", value: "value2")
        XCTAssertEqual(spanShim1.getBaggageItem("key1"), "value2")
        XCTAssertEqual(spanShim2.getBaggageItem("key1"), "value2")
        XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: spanShim1.context()), TestUtils.contextBaggageToDictionary(context: spanShim2.context()))
    }

    func testBaggageParent() {
        let parentSpan = tracerShim.startSpan(spanName)
        parentSpan.setBaggageItem("key1", value: "value1")
        let childSpan = tracerShim.startSpan(spanName, childOf: parentSpan.context()) as! SpanShim
        XCTAssertEqual(childSpan.getBaggageItem("key1"), "value1")
        XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: parentSpan.context()), TestUtils.contextBaggageToDictionary(context: childSpan.context()))
        childSpan.finish()
        parentSpan.finish()
    }

    func testParentNullContextShim() {
        let parentSpan = tracerShim.startSpan(spanName)
        let childSpan = tracerShim.startSpan(spanName, childOf: parentSpan.context()) as! SpanShim
        XCTAssertEqual(TestUtils.contextBaggageToDictionary(context: childSpan.context()).count, 0)
        childSpan.finish()
        parentSpan.finish()
    }
}
