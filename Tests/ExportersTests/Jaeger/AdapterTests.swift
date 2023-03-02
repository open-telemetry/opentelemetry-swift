/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

import Foundation

@testable import JaegerExporter
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import Thrift
import XCTest

class AdapterTests: XCTestCase {
    static let linkTraceId = "00000000000000000000000000cba123"
    static let linkSpanId = "0000000000fed456"
    static let traceId = "00000000000000000000000000abc123"
    static let spanId = "0000000000def456"
    static let parentSpanId = "0000000000aef789"

    let microsecondsInSecond: Double = 1000000

    func testProtoSpans() {
        let duration = 900 // microseconds
        let startMicroseconds = UInt64(Date().timeIntervalSince1970 * microsecondsInSecond)
        let endMicroseconds = startMicroseconds + UInt64(duration)

        let span = getSpanData(startMicroseconds: startMicroseconds, endMicroseconds: endMicroseconds)
        let spans = [span]

        let jaegerSpans = Adapter.toJaeger(spans: spans)

        // the span contents are checked somewhere else
        XCTAssertEqual(jaegerSpans.count, 1)
    }

    func testProtoSpan() {
        let duration = 900 // microseconds
        let startMicroseconds = UInt64(Date().timeIntervalSince1970 * microsecondsInSecond)
        let endMicroseconds = startMicroseconds + UInt64(duration)

        let span = getSpanData(startMicroseconds: startMicroseconds, endMicroseconds: endMicroseconds)

        // test
        let jaegerSpan = Adapter.toJaeger(span: span)

        XCTAssertEqual(span.traceId.hexString, String(format: "%016llx", jaegerSpan.traceIdHigh) + String(format: "%016llx", jaegerSpan.traceIdLow))
        XCTAssertEqual(span.spanId.hexString, String(format: "%016llx", jaegerSpan.spanId))
        XCTAssertEqual("GET /api/endpoint", jaegerSpan.operationName)
        XCTAssertEqual(Int64(startMicroseconds), jaegerSpan.startTime)
        XCTAssertEqual(duration, Int(jaegerSpan.duration))

        XCTAssertEqual(jaegerSpan.tags?.count, 4)
        var tag = getTag(tagsList: jaegerSpan.tags, key: Adapter.keySpanKind)
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.vStr, "SERVER")
        tag = getTag(tagsList: jaegerSpan.tags, key: Adapter.keySpanStatusCode)
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.vLong, 0)
        tag = getTag(tagsList: jaegerSpan.tags, key: Adapter.keySpanStatusMessage)
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.vStr, "")

        XCTAssertEqual(jaegerSpan.logs?.count, 1)
        let log = jaegerSpan.logs?.first
        tag = getTag(tagsList: log?.fields, key: Adapter.keyLogMessage)
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.vStr, "the log message")
        tag = getTag(tagsList: log?.fields, key: "foo")
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.vStr, "bar")

        XCTAssertEqual(jaegerSpan.references?.count, 2)

        AdapterTests.assertHasFollowsFrom(jaegerSpan: jaegerSpan)
        AdapterTests.assertHasParent(jaegerSpan: jaegerSpan)
    }

    func testJaegerLogs() {
        // prepare
        let event = getTimedEvent()

        // test
        let logs = Adapter.toJaegerLogs(events: [event])

        // verify
        XCTAssertEqual(logs.count, 1)
    }

    func testJaegerLog() {
        // prepare
        let event = getTimedEvent()

        // test
        let log = Adapter.toJaegerLog(event: event)

        // verify
        XCTAssertEqual(log.fields.count, 2)

        var tag = getTag(tagsList: log.fields, key: Adapter.keyLogMessage)
        XCTAssertNotNil(tag)
        XCTAssertEqual("the log message", tag?.vStr)
        tag = getTag(tagsList: log.fields, key: "foo")
        XCTAssertNotNil(tag)
        XCTAssertEqual("bar", tag?.vStr)
    }

    func testTags() {
        // prepare
        let valueB = AttributeValue.bool(true)

        // test
        let tags = Adapter.toJaegerTags(attributes: ["valueB": valueB])

        // verify
        // the actual content is checked in some other test
        XCTAssertEqual(1, tags.count)
    }

    func testKeyValue() {
        // prepare
        let valueB = AttributeValue.bool(true)
        let valueD = AttributeValue.double(1.0)
        let valueI = AttributeValue.int(2)
        let valueS = AttributeValue.string("foobar")
        let valueArrayB = AttributeValue.boolArray([true, false])
        let valueArrayD = AttributeValue.doubleArray([1.2, 4.5])
        let valueArrayI = AttributeValue.intArray([12345, 67890])
        let valueArrayS = AttributeValue.stringArray(["foobar", "barfoo"])

        // test
        let kvB = Adapter.toJaegerTag(key: "valueB", attrib: valueB)
        let kvD = Adapter.toJaegerTag(key: "valueD", attrib: valueD)
        let kvI = Adapter.toJaegerTag(key: "valueI", attrib: valueI)
        let kvS = Adapter.toJaegerTag(key: "valueS", attrib: valueS)
        let kvArrayB = Adapter.toJaegerTag(key: "valueArrayB", attrib: valueArrayB)
        let kvArrayD = Adapter.toJaegerTag(key: "valueArrayD", attrib: valueArrayD)
        let kvArrayI = Adapter.toJaegerTag(key: "valueArrayI", attrib: valueArrayI)
        let kvArrayS = Adapter.toJaegerTag(key: "valueArrayS", attrib: valueArrayS)

        // verify
        XCTAssertTrue(kvB.vBool ?? false)
        XCTAssertEqual(TagType.bool, kvB.vType)
        XCTAssertEqual(kvD.vDouble, 1.0)
        XCTAssertEqual(TagType.double, kvD.vType)
        XCTAssertEqual(kvI.vLong, 2)
        XCTAssertEqual(TagType.long, kvI.vType)
        XCTAssertEqual("foobar", kvS.vStr)
        XCTAssertEqual(TagType.string, kvS.vType)
        XCTAssertEqual("[true,false]", kvArrayB.vStr)
        XCTAssertEqual(TagType.string, kvArrayB.vType)
        XCTAssertEqual("[1.2,4.5]", kvArrayD.vStr)
        XCTAssertEqual(TagType.string, kvArrayD.vType)
        XCTAssertEqual("[12345,67890]", kvArrayI.vStr)
        XCTAssertEqual(TagType.string, kvArrayI.vType)
        XCTAssertEqual("[\"foobar\",\"barfoo\"]", kvArrayS.vStr)
        XCTAssertEqual(TagType.string, kvArrayS.vType)
    }

    func testSpanRefs() {
        // prepare
        let link = SpanData.Link(context: createSpanContext(traceId: "00000000000000000000000000cba123", spanId: "0000000000fed456"))

        // test
        let spanRefs = Adapter.toSpanRefs(links: [link])

        // verify
        XCTAssertEqual(1, spanRefs.count) // the actual span ref is tested in another test
    }

    func testSpanRef() {
        // prepare
        let link = SpanData.Link(context: createSpanContext(traceId: AdapterTests.traceId, spanId: AdapterTests.spanId))

        // test
        let spanRef = Adapter.toSpanRef(link: link)

        // verify

        XCTAssertEqual(AdapterTests.traceId, String(format: "%016llx", spanRef.traceIdHigh) + String(format: "%016llx", spanRef.traceIdLow))
        XCTAssertEqual(AdapterTests.spanId, String(format: "%016llx", spanRef.spanId))
        XCTAssertEqual(spanRef.refType, SpanRefType.follows_from)
    }

    func testStatusNotOk() {
        let startMicroseconds = UInt64(Date().timeIntervalSince1970 * microsecondsInSecond)
        let endMicroseconds = startMicroseconds + 900

        let span = SpanData(traceId: TraceId(fromHexString: AdapterTests.traceId),
                            spanId: SpanId(fromHexString: AdapterTests.spanId),
                            traceFlags: TraceFlags(),
                            traceState: TraceState(),
                            resource: Resource(),
                            instrumentationScope: InstrumentationScopeInfo(),
                            name: "GET /api/endpoint",
                            kind: .server,
                            startTime: Date(timeIntervalSince1970: Double(startMicroseconds) / microsecondsInSecond),
                            status: .error(description: "GenericError"),
                            endTime: Date(timeIntervalSince1970: Double(endMicroseconds) / microsecondsInSecond),
                            hasRemoteParent: false)

        XCTAssertNotNil(Adapter.toJaeger(span: span))
    }

    func testSpanError() {
        let attributes = ["error.type": AttributeValue.string(self.name),
                          "error.message": AttributeValue.string("server error")]
        let startMicroseconds = UInt64(Date().timeIntervalSince1970 * microsecondsInSecond)
        let endMicroseconds = startMicroseconds + 900

        var span = SpanData(traceId: TraceId(fromHexString: AdapterTests.traceId),
                            spanId: SpanId(fromHexString: AdapterTests.spanId),
                            name: "GET /api/endpoint",
                            kind: .server,
                            startTime: Date(timeIntervalSince1970: Double(startMicroseconds) / microsecondsInSecond),
                            endTime: Date(timeIntervalSince1970: Double(endMicroseconds) / microsecondsInSecond))
        span.settingHasEnded(true)
        span.settingStatus(.error(description: "GenericError"))
        span.settingAttributes(attributes)

        let jaegerSpan = Adapter.toJaeger(span: span)
        let errorType = getTag(tagsList: jaegerSpan.tags, key: "error.type")
        XCTAssertEqual(self.name, errorType?.vStr)
        let error = getTag(tagsList: jaegerSpan.tags, key: "error")
        XCTAssertNotNil(error)
        XCTAssertEqual(true, error?.vBool)
    }

    private func getTimedEvent() -> SpanData.Event {
        let valueS = AttributeValue.string("bar")
        let attributes = ["foo": valueS]
        return SpanData.Event(name: "the log message", timestamp: Date(), attributes: attributes)
    }

    private func getSpanData(startMicroseconds: UInt64, endMicroseconds: UInt64) -> SpanData {
        let valueB = AttributeValue.bool(true)
        let attributes = ["valueB": valueB]

        let link = SpanData.Link(context: createSpanContext(traceId: AdapterTests.linkTraceId, spanId: AdapterTests.linkSpanId), attributes: attributes)

        return SpanData(traceId: TraceId(fromHexString: AdapterTests.traceId),
                        spanId: SpanId(fromHexString: AdapterTests.spanId),
                        traceFlags: TraceFlags(),
                        traceState: TraceState(),
                        parentSpanId: SpanId(fromHexString: AdapterTests.parentSpanId),
                        resource: Resource(),
                        instrumentationScope: InstrumentationScopeInfo(),
                        name: "GET /api/endpoint",
                        kind: .server,
                        startTime: Date(timeIntervalSince1970: Double(startMicroseconds) / microsecondsInSecond),
                        attributes: attributes,
                        events: [getTimedEvent()],
                        links: [link],
                        status: Status.ok,
                        endTime: Date(timeIntervalSince1970: Double(endMicroseconds) / microsecondsInSecond),
                        hasRemoteParent: false)
    }

    private func createSpanContext(traceId: String, spanId: String) -> SpanContext {
        return SpanContext.create(traceId: TraceId(fromHexString: traceId), spanId: SpanId(fromHexString: spanId), traceFlags: TraceFlags(), traceState: TraceState())
    }

    private func getTag(tagsList: TList<Tag>?, key: String) -> Tag? {
        return tagsList?.first { $0.key == key }
    }

    private static func assertHasFollowsFrom(jaegerSpan: JaegerExporter.Span) {
        var found = false
        for spanRef in jaegerSpan.references! {
            if spanRef.refType == .follows_from {
                XCTAssertEqual(TraceId(fromHexString: linkTraceId).idHi, UInt64(spanRef.traceIdHigh))
                XCTAssertEqual(TraceId(fromHexString: linkTraceId).idLo, UInt64(spanRef.traceIdLow))
                XCTAssertEqual(SpanId(fromHexString: linkSpanId).id, UInt64(spanRef.spanId))
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    private static func assertHasParent(jaegerSpan: JaegerExporter.Span) {
        var found = false
        for spanRef in jaegerSpan.references! {
            if spanRef.refType == .child_of {
                XCTAssertEqual(TraceId(fromHexString: traceId).idHi, UInt64(spanRef.traceIdHigh))
                XCTAssertEqual(TraceId(fromHexString: traceId).idLo, UInt64(spanRef.traceIdLow))
                XCTAssertEqual(SpanId(fromHexString: parentSpanId).id, UInt64(spanRef.spanId))
                found = true
            }
        }
        XCTAssertTrue(found)
    }
}

#endif
