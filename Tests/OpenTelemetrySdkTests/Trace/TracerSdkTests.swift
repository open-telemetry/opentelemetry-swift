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
@testable import OpenTelemetrySdk
import XCTest

class TracerSdkTests: XCTestCase {
    let spanName = "span_name"
    let instrumentationLibraryName = "TracerSdkTest"
    let instrumentationLibraryVersion = "semver:0.2.0"
    var instrumentationLibraryInfo: InstrumentationLibraryInfo!
    var span = SpanMock()
    var spanProcessor = SpanProcessorMock()
    var tracerSdkFactory = TracerSdkRegistry()
    var tracer: TracerSdk!

    override func setUp() {
        instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)
        tracer = (tracerSdkFactory.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk)
    }

    func testDefaultGetCurrentSpan() {
        XCTAssertNil(tracer.currentSpan)
    }

    func testDefaultSpanBuilder() {
        XCTAssertTrue(tracer.spanBuilder(spanName: spanName) is SpanBuilderSdk)
    }

    func testDefaultHttpTextFormat() {
        XCTAssertTrue(tracer.textFormat is HttpTraceContextFormat)
    }

    func testDefaultBinaryFormat() {
        XCTAssertTrue(tracer.binaryFormat is BinaryTraceContextFormat)
    }

    func testGetCurrentSpan() {
        XCTAssertNil(tracer.currentSpan)
        // Make sure context is detached even if test fails.
        // TODO: Check context bahaviour
//        let origContext = ContextUtils.withSpan(span)
//        XCTAssertTrue(tracer.currentSpan === span)
//        XCTAssertTrue(tracer.currentSpan is DefaultSpan)
    }

    func testGetCurrentSpan_WithSpan() {
        XCTAssertNil(tracer.currentSpan)
        var ws = tracer.withSpan(span)
        XCTAssertTrue(tracer.currentSpan === span)
        ws.close()
        XCTAssertNil(tracer.currentSpan)
    }

    func testGetInstrumentationLibraryInfo() {
        XCTAssertEqual(tracer.instrumentationLibraryInfo, instrumentationLibraryInfo)
    }

    func testPropagatesInstrumentationLibraryInfoToSpan() {
        let readableSpan = tracer.spanBuilder(spanName: "spanName").startSpan() as! ReadableSpan
        XCTAssertEqual(readableSpan.instrumentationLibraryInfo, instrumentationLibraryInfo)
    }
}
