/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class JaegerPropagatorTests: XCTestCase {
    let traceIdHexString = "000000000000004d0000000000000016"
    var traceId: TraceId!
    let traceIdShortHexString = "00000000000000000000000000236f2e"
    var traceIdShort: TraceId!
    let spanIdHexString = "0000000000017c29"
    var spanId: SpanId!

    let deprecatedParentSpan = 0

    let jaegerPropagator = JaegerPropagator()
    let setter = TestSetter()
    let getter = TestGetter()

    override func setUp() {
        traceId = TraceId(fromHexString: traceIdHexString)
        traceIdShort = TraceId(fromHexString: traceIdShortHexString)
        spanId = SpanId(fromHexString: spanIdHexString)
    }

    func testInjectInvalidContext() {
        var carrier = [String: String]()
        jaegerPropagator.inject(spanContext: SpanContext.create(traceId: TraceId.invalid,
                                                                spanId: SpanId.invalid,
                                                                traceFlags: TraceFlags().settingIsSampled(true),
                                                                traceState: TraceState()),
                                carrier: &carrier,
                                setter: setter)
        XCTAssertEqual(carrier.count, 0)
    }

    func testInjectSampledContext() throws {
        var carrier = [String: String]()

        jaegerPropagator.inject(spanContext: SpanContext.create(traceId: traceId,
                                                                spanId: spanId,
                                                                traceFlags: TraceFlags().settingIsSampled(true),
                                                                traceState: TraceState()),
                                carrier: &carrier,
                                setter: setter)
        XCTAssertEqual(carrier.first?.key, JaegerPropagator.propagationHeader)

        let desired = generateTraceIdHeaderValue(traceId: traceIdHexString,
                                                 spanId: spanIdHexString,
                                                 parentSpan: JaegerPropagator.deprecatedParentSpan,
                                                 sampled: "1")
        XCTAssertEqual(carrier.first?.value, desired)
    }

    func testInjectNotSampledContext() throws {
        var carrier = [String: String]()

        jaegerPropagator.inject(spanContext: SpanContext.create(traceId: traceId,
                                                                spanId: spanId,
                                                                traceFlags: TraceFlags().settingIsSampled(false),
                                                                traceState: TraceState()),
                                carrier: &carrier,
                                setter: setter)
        XCTAssertEqual(carrier.first?.key, JaegerPropagator.propagationHeader)

        let desired = generateTraceIdHeaderValue(traceId: traceIdHexString,
                                                 spanId: spanIdHexString,
                                                 parentSpan: JaegerPropagator.deprecatedParentSpan,
                                                 sampled: "0")
        XCTAssertEqual(carrier.first?.value, desired)
    }

    func testExtractNothing() {
        let carrier = [String: String]()
        XCTAssertNil(jaegerPropagator.extract(carrier: carrier, getter: getter))
    }

    func testExtractEmptyHeaderValue() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = ""
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractNotEnoughParts() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = "aa:bb:cc"
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractTooManyParts() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = "aa:bb:cc:dd:ee"
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidTraceId() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: "abcdefghijklmnopabcdefghijklmnop", spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidTraceIdSize() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString + "00", spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidSpanId() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: "abcdefghijklmnop", parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidSpanIdSize() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString + "0", parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidFlags() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidFlagsSize() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "10220")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractInvalidFlagsNonNumeric() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "abcdefr")
        XCTAssertNil(jaegerPropagator.extract(carrier: headers, getter: getter))
    }

    func testExtractSampledContext() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "1")

        let desiredContext = SpanContext.createFromRemoteParent(traceId: traceId,
                                                                spanId: spanId,
                                                                traceFlags: TraceFlags().settingIsSampled(true),
                                                                traceState: TraceState())

        XCTAssertEqual(jaegerPropagator.extract(carrier: headers, getter: getter), desiredContext)
    }

    func testExtractNotSampledContext() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")

        let desiredContext = SpanContext.createFromRemoteParent(traceId: traceId,
                                                                spanId: spanId,
                                                                traceFlags: TraceFlags().settingIsSampled(false),
                                                                traceState: TraceState())

        XCTAssertEqual(jaegerPropagator.extract(carrier: headers, getter: getter), desiredContext)
    }

    func testExtractSampledContextShortTraceId() {
        var headers = [String: String]()
        headers[JaegerPropagator.propagationHeader] = generateTraceIdHeaderValue(traceId: traceIdShortHexString, spanId: spanIdHexString, parentSpan: JaegerPropagator.deprecatedParentSpan, sampled: "0")

        let desiredContext = SpanContext.createFromRemoteParent(traceId: traceIdShort,
                                                                spanId: spanId,
                                                                traceFlags: TraceFlags().settingIsSampled(false),
                                                                traceState: TraceState())

        XCTAssertEqual(jaegerPropagator.extract(carrier: headers, getter: getter), desiredContext)
    }

    func testExtract_SampledContext_Int() {
        var carrier = [String: String]()
        carrier[B3Propagator.traceIdHeader] = traceIdHexString
        carrier[B3Propagator.spanIdHeader] = spanIdHexString
        carrier[B3Propagator.sampledHeader] = B3Propagator.trueInt

        //    XCTAssertEqual(b3Propagator.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }

    private func generateTraceIdHeaderValue(traceId: String, spanId: String, parentSpan: String, sampled: String) -> String {
        let string: String = traceId +
            String(JaegerPropagator.propagationHeaderDelimiter) +
            spanId +
            String(JaegerPropagator.propagationHeaderDelimiter) +
            parentSpan +
            String(JaegerPropagator.propagationHeaderDelimiter) +
            sampled
        return string
    }
}
