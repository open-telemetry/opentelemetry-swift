/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryTestUtils
import XCTest
import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryConcurrency

private typealias OpenTelemetry = OpenTelemetryConcurrency.OpenTelemetry

final class ConcurrencyTests: OpenTelemetryContextTestCase {
    var oldTracerProvider: TracerProvider?

    override func setUp() async throws {
        try await super.setUp()
        oldTracerProvider = OpenTelemetry.instance.tracerProvider.inner
        OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderSdk())
    }

    override func tearDown() async throws {
        OpenTelemetry.registerTracerProvider(tracerProvider: self.oldTracerProvider!)
        try await super.tearDown()
    }

    func testBasicSpan() {
        // Attempting to use `startSpan` or `setActive` here will cause a build error since we're using `OpenTelemetryConcurrency.OpenTelemetry` instead of `OpenTelemetryApi.OpenTelemetry`
        OpenTelemetry.instance.tracerProvider
            .get(instrumentationName: "test", instrumentationVersion: nil)
            .spanBuilder(spanName: "basic")
            .withActiveSpan { span in
                XCTAssertIdentical(OpenTelemetry.instance.contextProvider.activeSpan, span)
            }

        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }
}
