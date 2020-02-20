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

    func testProtoSpans() {
        let duration = 900 // ms
        let startMs = Int(Date().timeIntervalSince1970 * 1000)
        let endMs = startMs + duration

        let span = getSpanData(startMs: startMs, endMs: endMs)
        let spans = [span]

        let jaegerSpans = Adapter.toJaeger(spans: spans)

        // the span contents are checked somewhere else
        XCTAssertEqual(jaegerSpans.count, 1)
    }

    func testProtoSpan() {
        let duration = 900 // ms
        let startMs = Int(Date().timeIntervalSince1970 * 1000)
        let endMs = startMs + duration

        let span = getSpanData(startMs: startMs, endMs: endMs)

        // test
        let jaegerSpan = Adapter.toJaeger(span: span)

        XCTAssertEqual(span.traceId.hexString, String(format: "%016llx", jaegerSpan.traceIdHigh) + String(format: "%016llx", jaegerSpan.traceIdLow))
        XCTAssertEqual(span.spanId.hexString, String(format: "%016llx", jaegerSpan.spanId))
        XCTAssertEqual("GET /api/endpoint", jaegerSpan.operationName)
        XCTAssertEqual(startMs, Int(jaegerSpan.startTime))
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
        let timedEvent = getTimedEvent()

        // test
        let logs = Adapter.toJaegerLogs(timedEvents: [timedEvent])

        // verify
        XCTAssertEqual(logs.count, 1)
    }

    func testJaegerLog() {
        // prepare
        let timedEvent = getTimedEvent()

        // test
        let log = Adapter.toJaegerLog(timedEvent: timedEvent)

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

        // test
        let kvB = Adapter.toJaegerTag(key: "valueB", attrib: valueB)
        let kvD = Adapter.toJaegerTag(key: "valueD", attrib: valueD)
        let kvI = Adapter.toJaegerTag(key: "valueI", attrib: valueI)
        let kvS = Adapter.toJaegerTag(key: "valueS", attrib: valueS)

        // verify
        XCTAssertTrue(kvB.vBool ?? false)
        XCTAssertEqual(TagType.bool, kvB.vType)
        XCTAssertEqual(kvD.vDouble, 1.0)
        XCTAssertEqual(TagType.double, kvD.vType)
        XCTAssertEqual(kvI.vLong, 2)
        XCTAssertEqual(TagType.long, kvI.vType)
        XCTAssertEqual("foobar", kvS.vStr)
        XCTAssertEqual(TagType.string, kvS.vType)
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
        let startMs = Int(Date().timeIntervalSince1970 * 1000)
        let endMs = startMs + 900

        let span = SpanData(traceId: TraceId(fromHexString: AdapterTests.traceId),
                            spanId: SpanId(fromHexString: AdapterTests.spanId),
                            traceFlags: TraceFlags(),
                            traceState: TraceState(),
                            resource: Resource(),
                            instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                            name: "GET /api/endpoint",
                            kind: .server,
                            startEpochNanos: startMs * 1000,
                            status: Status.cancelled,
                            endEpochNanos: endMs * 1000,
                            hasRemoteParent: false)

        XCTAssertNotNil(Adapter.toJaeger(span: span))
    }

    private func getTimedEvent() -> SpanData.TimedEvent {
        let epochNanos = Int(Date().timeIntervalSince1970 * 1000000)
        let valueS = AttributeValue.string("bar")
        let attributes = ["foo": valueS]
        return SpanData.TimedEvent(epochNanos: epochNanos, name: "the log message", attributes: attributes)
    }

    private func getSpanData(startMs: Int, endMs: Int) -> SpanData {
        let valueB = AttributeValue.bool(true)
        let attributes = ["valueB": valueB]

        let link = SpanData.Link(context: createSpanContext(traceId: AdapterTests.linkTraceId, spanId: AdapterTests.linkSpanId), attributes: attributes)

        return SpanData(traceId: TraceId(fromHexString: AdapterTests.traceId),
                        spanId: SpanId(fromHexString: AdapterTests.spanId),
                        traceFlags: TraceFlags(),
                        traceState: TraceState(),
                        parentSpanId: SpanId(fromHexString: AdapterTests.parentSpanId),
                        resource: Resource(),
                        instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                        name: "GET /api/endpoint",
                        kind: .server,
                        startEpochNanos: startMs * 1000,
                        attributes: attributes,
                        timedEvents: [getTimedEvent()],
                        links: [link],
                        status: Status.ok,
                        endEpochNanos: endMs * 1000,
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
