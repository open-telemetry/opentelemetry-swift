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

class RecordEventsReadableSpanTest: XCTestCase {
    class TestEvent: Event {
        var name: String {
            return "event3"
        }

        var attributes: [String: AttributeValue] {
            return [String: AttributeValue]()
        }
    }

    let spanName = "MySpanName"
    let spanNewName = "NewName"
    let nanosPerSecond = 1000000000
    let millisPerSecond = 1000
    let idsGenerator: IdsGenerator = RandomIdsGenerator()
    var traceId: TraceId!
    var spanId: SpanId!
    var parentSpanId: SpanId!
    let expectedHasRemoteParent = true
    var spanContext: SpanContext!
    let startEpochNanos: Int = 1000123789654
    var testClock: TestClock!
    let resource = Resource()
    let instrumentationLibraryInfo = InstrumentationLibraryInfo(name: "theName", version: nil)
    var attributes = [String: AttributeValue]()
    var expectedAttributes = [String: AttributeValue]()
    var link: SpanData.Link!
    let spanProcessor = SpanProcessorMock()

    override func setUp() {
        traceId = idsGenerator.generateTraceId()
        spanId = idsGenerator.generateSpanId()
        parentSpanId = idsGenerator.generateSpanId()
        spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
        testClock = TestClock(nanos: startEpochNanos)
        link = SpanData.Link(context: spanContext)
        attributes["MyStringAttributeKey"] = AttributeValue.string("MyStringAttributeValue")
        attributes["MyLongAttributeKey"] = AttributeValue.int(123)
        attributes["MyBooleanAttributeKey"] = AttributeValue.bool(false)
        expectedAttributes.merge(attributes) { first, _ in first }
        expectedAttributes["MySingleStringAttributeKey"] = AttributeValue.string("MySingleStringAttributeValue")
    }

    func testNothingChangedAfterEnd() {
        let span = createTestSpan(kind: .internal)
        span.end()
        // Check that adding trace events or update fields after Span#end() does not throw any thrown
        // and are ignored.
        spanDoWork(span: span, status: .cancelled)
        let spanData = span.toSpanData()
        verifySpanData(spanData: spanData,
                       attributes: [String: AttributeValue](),
                       timedEvents: [SpanData.TimedEvent](),
                       links: [link],
                       spanName: spanName,
                       startEpochNanos: startEpochNanos,
                       endEpochNanos: startEpochNanos,
                       status: .ok,
                       hasEnded: true)
    }

    func testEndSpanTwice_DoNotCrash() {
        let span = createTestSpan(kind: .internal)
        XCTAssertFalse(span.hasEnded)
        span.end()
        XCTAssertTrue(span.hasEnded)
        span.end()
        XCTAssertTrue(span.hasEnded)
    }

    func testToSpanData_ActiveSpan() {
        let span = createTestSpan(kind: .internal)
        XCTAssertFalse(span.hasEnded)
        spanDoWork(span: span, status: nil)
        let spanData = span.toSpanData()
        let timedEvent = SpanData.TimedEvent(epochNanos: startEpochNanos + nanosPerSecond, name: "event2", attributes: [String: AttributeValue]())
        verifySpanData(spanData: spanData,
                       attributes: expectedAttributes,
                       timedEvents: [timedEvent],
                       links: [link],
                       spanName: spanNewName,
                       startEpochNanos: startEpochNanos,
                       endEpochNanos: testClock.now,
                       status: .ok,
                       hasEnded: false)
        XCTAssertFalse(span.hasEnded)
        span.end()
        XCTAssertTrue(span.hasEnded)
    }

    func testToSpanData_EndedSpan() {
        let span = createTestSpan(kind: .internal)
        spanDoWork(span: span, status: .cancelled)
        span.end()
        XCTAssertEqual(spanProcessor.onEndCalledTimes, 1)
        let spanData = span.toSpanData()
        let timedEvent = SpanData.TimedEvent(epochNanos: startEpochNanos + nanosPerSecond, name: "event2", attributes: [String: AttributeValue]())
        verifySpanData(spanData: spanData,
                       attributes: expectedAttributes,
                       timedEvents: [timedEvent],
                       links: [link],
                       spanName: spanNewName,
                       startEpochNanos: startEpochNanos,
                       endEpochNanos: testClock.now,
                       status: .cancelled,
                       hasEnded: true)
    }

    func testToSpanData_RootSpan() {
        let span = createTestRootSpan()
        spanDoWork(span: span, status: nil)
        span.end()
        let spanData = span.toSpanData()
        XCTAssertNil(spanData.parentSpanId)
    }

    func testToSpanData_WithInitialAttributes() {
        let span = createTestSpan(attributes: attributes)
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, attributes.count)
    }

    func testSetStatus() {
        let span = createTestSpan(kind: .consumer)
        testClock.advanceMillis(millisPerSecond)
        XCTAssertEqual(span.toSpanData().status, Status.ok)
        span.status = .cancelled
        XCTAssertEqual(span.toSpanData().status, Status.cancelled)
        span.end()
        XCTAssertEqual(span.toSpanData().status, Status.cancelled)
    }

    func testGetSpanKind() {
        let span = createTestSpan(kind: .server)
        XCTAssertEqual(span.toSpanData().kind, SpanKind.server)
        span.end()
    }

    func testGetInstrumentationLibraryInfo() {
        let span = createTestSpan(kind: .client)
        XCTAssertEqual(span.instrumentationLibraryInfo, instrumentationLibraryInfo)
        span.end()
    }

    func testGetSpanHasRemoteParent() {
        let span = createTestSpan(kind: .server)
        XCTAssertTrue(span.toSpanData().hasRemoteParent)
        span.end()
    }

    func testGetAndUpdateSpanName() {
        let span = createTestRootSpan()
        XCTAssertEqual(span.name, spanName)
        span.name = spanNewName
        XCTAssertEqual(span.name, spanNewName)
        span.end()
    }

    func testGetLatencyNs_ActiveSpan() {
        let span = createTestSpan(kind: .internal)
        testClock.advanceMillis(millisPerSecond)
        let elapsedTimeNanos1 = testClock.now - startEpochNanos
        XCTAssertEqual(span.latencyNanos, elapsedTimeNanos1)
        testClock.advanceMillis(millisPerSecond)
        let elapsedTimeNanos2 = testClock.now - startEpochNanos
        XCTAssertEqual(span.latencyNanos, elapsedTimeNanos2)
        span.end()
    }

    func testGetLatencyNs_EndedSpan() {
        let span = createTestSpan(kind: .internal)
        testClock.advanceMillis(millisPerSecond)
        span.end()
        let elapsedTimeNanos = testClock.now - startEpochNanos
        XCTAssertEqual(span.latencyNanos, elapsedTimeNanos)
        testClock.advanceMillis(millisPerSecond)
        XCTAssertEqual(span.latencyNanos, elapsedTimeNanos)
    }

    func testSetAttribute() {
        let span = createTestRootSpan()
        span.setAttribute(key: "StringKey", value: "StringVal")
        span.setAttribute(key: "EmptyStringkey", value: "")
        span.setAttribute(key: "NilStringAttributeValue", value: AttributeValue.string(nil))
        span.setAttribute(key: "EmptyStringAttributeValue", value: AttributeValue.string(""))
        span.setAttribute(key: "LongKey", value: 1000)
        span.setAttribute(key: "DoubleKey", value: 10.0)
        span.setAttribute(key: "BooleanKey", value: false)
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, 4)
    }

    func testAddEvent() {
        let span = createTestRootSpan()
        span.addEvent(name: "event1")
        span.addEvent(name: "event2", attributes: attributes)
        span.addEvent(event: TestEvent())
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.timedEvents.count, 3)
    }

    func testDroppingAttributes() {
        let maxNumberOfAttributes = 8
        let traceConfig = TraceConfig().settingMaxNumberOfAttributes(maxNumberOfAttributes)
        let span = createTestSpan(config: traceConfig) //
        for i in 0 ..< 2 * maxNumberOfAttributes {
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(i))
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes) //
        for i in 0 ..< maxNumberOfAttributes {
            let expectedValue = AttributeValue.int(i + maxNumberOfAttributes)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i + maxNumberOfAttributes)"], expectedValue)
        }
        span.end()
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes) //
        for i in 0 ..< maxNumberOfAttributes {
            let expectedValue = AttributeValue.int(i + maxNumberOfAttributes)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i + maxNumberOfAttributes)"], expectedValue)
        }
    }

    func testDroppingAndAddingAttributes() {
        let maxNumberOfAttributes = 8
        let traceConfig = TraceConfig().settingMaxNumberOfAttributes(maxNumberOfAttributes)
        let span = createTestSpan(config: traceConfig)
        for i in 0 ..< 2 * maxNumberOfAttributes {
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(i))
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes) //
        for i in 0 ..< maxNumberOfAttributes {
            let expectedValue = AttributeValue.int(i + maxNumberOfAttributes)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i + maxNumberOfAttributes)"], expectedValue)
        } //
        for i in 0 ..< maxNumberOfAttributes / 2 {
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(i))
        }
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes)
        // Test that we still have in the attributes map the latest maxNumberOfAttributes / 2 entries.
        for i in 0 ..< maxNumberOfAttributes / 2 {
            let val = i + maxNumberOfAttributes * 3 / 2
            let expectedValue = AttributeValue.int(val)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(val)"], expectedValue)
        }
        // Test that we have the newest re-added initial entries.
        for i in 0 ..< maxNumberOfAttributes / 2 {
            let expectedValue = AttributeValue.int(i)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i)"], expectedValue)
        }
        span.end()
    }

    func testDroppingEvents() {
        let maxNumberOfEvents = 8
        let traceConfig = TraceConfig().settingMaxNumberOfEvents(maxNumberOfEvents)
        let span = createTestSpan(config: traceConfig)
        for _ in 0 ..< 2 * maxNumberOfEvents {
            span.addEvent(name: "event2", attributes: [String: AttributeValue]())
            testClock.advanceMillis(millisPerSecond)
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.timedEvents.count, maxNumberOfEvents) //
        for i in 0 ..< maxNumberOfEvents {
            let expectedEvent = SpanData.TimedEvent(epochNanos: startEpochNanos + Int(maxNumberOfEvents + i) * nanosPerSecond,
                                                    name: "event2",
                                                    attributes: [String: AttributeValue]())
            XCTAssertEqual(spanData.timedEvents[i], expectedEvent)
            XCTAssertEqual(spanData.totalRecordedEvents, 2 * maxNumberOfEvents)
        }
        span.end()
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.timedEvents.count, maxNumberOfEvents)
        for i in 0 ..< maxNumberOfEvents {
            let expectedEvent = SpanData.TimedEvent(epochNanos: startEpochNanos + Int(maxNumberOfEvents + i) * nanosPerSecond,
                                                    name: "event2",
                                                    attributes: [String: AttributeValue]())
            XCTAssertEqual(spanData.timedEvents[i], expectedEvent)
        }
    }

    func testAsSpanData() {
        let name = "GreatSpan"
        let kind = SpanKind.server
        let traceId = idsGenerator.generateTraceId()
        let spanId = idsGenerator.generateSpanId()
        let parentSpanId = idsGenerator.generateSpanId()
        let traceConfig = TraceConfig()
        let spanProcessor = NoopSpanProcessor()
        let clock = TestClock()
        var labels = [String: String]()
        labels["foo"] = "bar"
        let resource = Resource(labels: labels)
        let attributes = TestUtils.generateRandomAttributes()
        var attributesWithCapacity = AttributesWithCapacity(capacity: 32)
        attributesWithCapacity.updateValues(attributes: attributes)

        let event1Attributes = TestUtils.generateRandomAttributes()
        let event2Attributes = TestUtils.generateRandomAttributes()
        let context = SpanContext.create(traceId: traceId,
                                         spanId: spanId,
                                         traceFlags: TraceFlags(),
                                         traceState: TraceState())
        let link1 = SpanData.Link(context: context, attributes: TestUtils.generateRandomAttributes())
        let links = [link1]

        let readableSpan = RecordEventsReadableSpan.startSpan(context: context,
                                                              name: name,
                                                              instrumentationLibraryInfo: instrumentationLibraryInfo,
                                                              kind: kind,
                                                              parentSpanId: parentSpanId,
                                                              hasRemoteParent: false,
                                                              traceConfig: traceConfig,
                                                              spanProcessor: spanProcessor,
                                                              clock: clock,
                                                              resource: resource,
                                                              attributes: attributesWithCapacity,
                                                              links: links,
                                                              totalRecordedLinks: 1,
                                                              startEpochNanos: 0)
        let startEpochNanos = clock.now
        clock.advanceMillis(4)
        let firstEventTimeNanos = clock.now
        readableSpan.addEvent(name: "event1", attributes: event1Attributes)
        clock.advanceMillis(6)
        let secondEventTimeNanos = clock.now
        readableSpan.addEvent(name: "event2", attributes: event2Attributes)

        clock.advanceMillis(100)
        readableSpan.end()
        let endEpochNanos = clock.now
        let timedEvent1 = SpanData.TimedEvent(epochNanos: firstEventTimeNanos, name: "event1", attributes: event1Attributes)
        let timedEvent2 = SpanData.TimedEvent(epochNanos: secondEventTimeNanos, name: "event2", attributes: event2Attributes)
        let timedEvents = [timedEvent1, timedEvent2]
        let expected = SpanData(traceId: traceId,
                                spanId: spanId,
                                traceFlags: TraceFlags(),
                                traceState: TraceState(),
                                parentSpanId: parentSpanId,
                                resource: resource,
                                instrumentationLibraryInfo: instrumentationLibraryInfo,
                                name: name,
                                kind: kind,
                                startEpochNanos: startEpochNanos,
                                attributes: attributes,
                                timedEvents: timedEvents,
                                links: links,
                                status: .ok,
                                endEpochNanos: endEpochNanos,
                                hasRemoteParent: false,
                                hasEnded: true,
                                totalRecordedEvents: 2,
                                numberOfChildren: 0,
                                totalRecordedLinks: links.count)

        let result = readableSpan.toSpanData()
        XCTAssertEqual(expected, result)
    }

    private func createTestRootSpan() -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: TraceConfig(), parentSpanId: nil, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(attributes: [String: AttributeValue]) -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: TraceConfig(), parentSpanId: nil, attributes: attributes)
    }

    private func createTestSpan(kind: SpanKind) -> RecordEventsReadableSpan {
        return createTestSpan(kind: kind, config: TraceConfig(), parentSpanId: parentSpanId, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(config: TraceConfig) -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: config, parentSpanId: nil, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(kind: SpanKind, config: TraceConfig, parentSpanId: SpanId?, attributes: [String: AttributeValue]) -> RecordEventsReadableSpan {
        var attributesWithCapacity = AttributesWithCapacity(capacity: config.maxNumberOfAttributes)
        attributesWithCapacity.updateValues(attributes: attributes)

        let span = RecordEventsReadableSpan.startSpan(context: spanContext,
                                                      name: spanName,
                                                      instrumentationLibraryInfo: instrumentationLibraryInfo,
                                                      kind: kind,
                                                      parentSpanId: parentSpanId,
                                                      hasRemoteParent: true,
                                                      traceConfig: config,
                                                      spanProcessor: spanProcessor,
                                                      clock: testClock,
                                                      resource: resource,
                                                      attributes: attributesWithCapacity,
                                                      links: [link],
                                                      totalRecordedLinks: 1,
                                                      startEpochNanos: 0)
        XCTAssertEqual(spanProcessor.onStartCalledTimes, 1)
        return span
    }

    private func spanDoWork(span: RecordEventsReadableSpan, status: Status?) {
        span.setAttribute(key: "MySingleStringAttributeKey", value: AttributeValue.string("MySingleStringAttributeValue"))

        for attribute in attributes {
            span.setAttribute(key: attribute.key, value: attribute.value)
        }
        testClock.advanceMillis(millisPerSecond)
        span.addEvent(name: "event2", attributes: [String: AttributeValue]())
        testClock.advanceMillis(millisPerSecond)
        span.addChild()
        span.name = spanNewName
        span.status = status
    }

    private func verifySpanData(spanData: SpanData,
                                attributes: [String: AttributeValue],
                                timedEvents: [SpanData.TimedEvent],
                                links: [Link], spanName: String,
                                startEpochNanos: Int,
                                endEpochNanos: Int,
                                status: Status,
                                hasEnded: Bool) {
        XCTAssertEqual(spanData.traceId, traceId)
        XCTAssertEqual(spanData.spanId, spanId)
        XCTAssertEqual(spanData.parentSpanId, parentSpanId)
        XCTAssertEqual(spanData.hasRemoteParent, expectedHasRemoteParent)
        XCTAssertEqual(spanData.traceState, TraceState())
        XCTAssertEqual(spanData.resource, resource)
        XCTAssertEqual(spanData.instrumentationLibraryInfo, instrumentationLibraryInfo)
        XCTAssertEqual(spanData.name, spanName)
        XCTAssertEqual(spanData.attributes, attributes)
        XCTAssertEqual(spanData.timedEvents, timedEvents)
        XCTAssert(spanData.links == links)
        XCTAssertEqual(spanData.startEpochNanos, startEpochNanos)
        XCTAssertEqual(spanData.endEpochNanos, endEpochNanos)
        XCTAssertEqual(spanData.status?.canonicalCode, status.canonicalCode)
        XCTAssertEqual(spanData.hasEnded, hasEnded)
    }
}
