/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class SpanDataTests: XCTestCase {
    let startTime: Date = TestUtils.dateFromNanos(3000000000000 + 200)
    let endTime: Date = TestUtils.dateFromNanos(3001000000000 + 255)

    func testdefaultValues() {
        let spanData = createBasicSpan()
        XCTAssertFalse(spanData.parentSpanId?.isValid ?? false)
        XCTAssertEqual(spanData.attributes, [String: AttributeValue]())
        XCTAssertEqual(spanData.events, [SpanData.Event]())
        XCTAssertEqual(spanData.links.count, 0)
        XCTAssertEqual(InstrumentationLibraryInfo(), spanData.instrumentationLibraryInfo)
        XCTAssertFalse(spanData.hasRemoteParent)
    }

    private func createBasicSpan() -> SpanData {
        return SpanData(traceId: TraceId(),
                        spanId: SpanId(),
                        traceFlags: TraceFlags(),
                        traceState: TraceState(),
                        resource: Resource(),
                        instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                        name: "spanName",
                        kind: .server,
                        startTime: startTime,
                        endTime: endTime,
                        hasRemoteParent: false)
    }
}
