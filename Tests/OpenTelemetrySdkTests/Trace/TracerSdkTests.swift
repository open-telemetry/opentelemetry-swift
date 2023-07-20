/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest
import OpenTelemetryTestUtils

#if canImport(os.activity)
class TracerSdkTestsActivity: TracerSdkTestsBase {
    override class var contextManager: ContextManager { ActivityContextManager.instance }
}
#endif

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
class TracerSdkTestsServiceContext: TracerSdkTestsBase {
    override class var contextManager: ContextManager { ServiceContextManager() }
}

class TracerSdkTestsBase: ContextManagerTestCase {
    let spanName = "span_name"
    let instrumentationScopeName = "TracerSdkTest"
    let instrumentationScopeVersion = "semver:0.2.0"
    var instrumentationScopeInfo: InstrumentationScopeInfo!
    var span = SpanMock()
    var spanProcessor = SpanProcessorMock()
    var tracerSdkFactory = TracerProviderSdk()
    var tracer: TracerSdk!

    override func setUp() {
        instrumentationScopeInfo = InstrumentationScopeInfo(name: instrumentationScopeName, version: instrumentationScopeVersion)
        tracer = (tracerSdkFactory.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk)
    }

    func testDefaultGetCurrentSpan() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testDefaultSpanBuilder() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertTrue(tracer.spanBuilder(spanName: spanName) is SpanBuilderSdk)
    }

    func testGetCurrentSpan() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
        // Make sure context is detached even if test fails.
        // TODO: Check context bahaviour
        //        let origContext = ContextUtils.withSpan(span)
        //        XCTAssertTrue(tracer.currentSpan === span)
        //        XCTAssertTrue(tracer.currentSpan is PropagatedSpan)
    }

    func testGetCurrentSpan_WithSpan() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
        OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
            XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
        }

        span.end()
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testGetInstrumentationScopeInfo() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertEqual(tracer.instrumentationScopeInfo, instrumentationScopeInfo)
    }
    
    func testPropagatesInstrumentationScopeInfoToSpan() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        let readableSpan = tracer.spanBuilder(spanName: "spanName").startSpan() as? ReadableSpan
        XCTAssertEqual(readableSpan?.instrumentationScopeInfo, instrumentationScopeInfo)
    }
}
