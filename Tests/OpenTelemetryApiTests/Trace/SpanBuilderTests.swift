/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

fileprivate func createRandomPropagatedSpan() -> PropagatedSpan {
    return PropagatedSpan(context: SpanContext.create(traceId: TraceId.random(),
                                                      spanId: SpanId.random(),
                                                      traceFlags: TraceFlags(),
                                                      traceState: TraceState()))
}

class SpanBuilderTests: XCTestCase {
    let tracer = DefaultTracer.instance

    func testDoNotCrash_NoopImplementation() {
        let spanBuilder = tracer.spanBuilder(spanName: "MySpanName")
        spanBuilder.setSpanKind(spanKind: .server)
        spanBuilder.setParent(createRandomPropagatedSpan())
        spanBuilder.setParent(createRandomPropagatedSpan().context)
        spanBuilder.setNoParent()
        spanBuilder.addLink(spanContext: createRandomPropagatedSpan().context)
        spanBuilder.addLink(spanContext: createRandomPropagatedSpan().context, attributes: [String: AttributeValue]())
        spanBuilder.addLink(spanContext: createRandomPropagatedSpan().context, attributes: [String: AttributeValue]())
        spanBuilder.setAttribute(key: "key", value: "value")
        spanBuilder.setAttribute(key: "key", value: 12345)
        spanBuilder.setAttribute(key: "key", value: 0.12345)
        spanBuilder.setAttribute(key: "key", value: true)
        spanBuilder.setAttribute(key: "key", value: AttributeValue.string("value"))
        spanBuilder.setStartTime(time: Date())
        XCTAssert(spanBuilder.startSpan() is PropagatedSpan)
    }
}
