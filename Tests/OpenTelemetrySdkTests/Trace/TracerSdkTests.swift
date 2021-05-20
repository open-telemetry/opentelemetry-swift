/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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
    var tracerSdkFactory = TracerProviderSdk()
    var tracer: TracerSdk!

    override func setUp() {
        instrumentationLibraryInfo = InstrumentationLibraryInfo(name: instrumentationLibraryName, version: instrumentationLibraryVersion)
        tracer = (tracerSdkFactory.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk)
    }

    func testDefaultGetCurrentSpan() {
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testDefaultSpanBuilder() {
        XCTAssertTrue(tracer.spanBuilder(spanName: spanName) is SpanBuilderSdk)
    }

    func testDefaultTextMapPropagator() {
        XCTAssertTrue(tracer.textFormat is W3CTraceContextPropagator)
    }

    func testGetCurrentSpan() {
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
        // Make sure context is detached even if test fails.
        // TODO: Check context bahaviour
//        let origContext = ContextUtils.withSpan(span)
//        XCTAssertTrue(tracer.currentSpan === span)
//        XCTAssertTrue(tracer.currentSpan is PropagatedSpan)
    }

    func testGetCurrentSpan_WithSpan() {
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
        OpenTelemetry.instance.contextProvider.setActiveSpan(span)
        XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
        span.end()
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testGetInstrumentationLibraryInfo() {
        XCTAssertEqual(tracer.instrumentationLibraryInfo, instrumentationLibraryInfo)
    }

    func testPropagatesInstrumentationLibraryInfoToSpan() {
        let readableSpan = tracer.spanBuilder(spanName: "spanName").startSpan() as? ReadableSpan
        XCTAssertEqual(readableSpan?.instrumentationLibraryInfo, instrumentationLibraryInfo)
    }
}
