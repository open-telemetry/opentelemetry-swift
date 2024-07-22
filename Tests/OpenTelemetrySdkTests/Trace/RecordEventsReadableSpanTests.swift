/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class RecordEventsReadableSpanTest: XCTestCase {
    let spanName = "MySpanName"
    let spanNewName = "NewName"
    let nanosPerSecond: Int64 = 1000000000
    let millisPerSecond: Int64 = 1000
    let idGenerator: IdGenerator = RandomIdGenerator()
    var traceId: TraceId!
    var spanId: SpanId!
    var parentSpanId: SpanId!
    let expectedHasRemoteParent = true
    var spanContext: SpanContext!
    let startTime = Date(timeIntervalSinceReferenceDate: 0)
    var testClock: TestClock!
    let resource = Resource()
    let instrumentationScopeInfo = InstrumentationScopeInfo(name: "theName", version: nil)
    var attributes = [String: AttributeValue]()
    var expectedAttributes = [String: AttributeValue]()
    var link: SpanData.Link!
    let spanProcessor = SpanProcessorMock()

    override func setUp() {
        traceId = idGenerator.generateTraceId()
        spanId = idGenerator.generateSpanId()
        parentSpanId = idGenerator.generateSpanId()
        spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
        testClock = TestClock(timeInterval: startTime.timeIntervalSince1970)
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
        spanDoWork(span: span, status: .error(description: "GenericError"))
        let spanData = span.toSpanData()
        verifySpanData(spanData: spanData,
                       attributes: [String: AttributeValue](),
                       events: [SpanData.Event](),
                       links: [link],
                       spanName: spanName,
                       startTime: startTime,
                       endTime: startTime,
                       status: .unset,
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
        spanDoWork(span: span, status: .ok)
        let spanData = span.toSpanData()
        let event = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(1), attributes: [String: AttributeValue]())
        verifySpanData(spanData: spanData,
                       attributes: expectedAttributes,
                       events: [event],
                       links: [link],
                       spanName: spanNewName,
                       startTime: startTime,
                       endTime: testClock.now,
                       status: .ok,
                       hasEnded: false)
        XCTAssertFalse(span.hasEnded)
        span.end()
        XCTAssertTrue(span.hasEnded)
    }

    func testToSpanData_EndedSpan() {
        let span = createTestSpan(kind: .internal)
        spanDoWork(span: span, status: .ok)
        span.end()
        XCTAssertEqual(spanProcessor.onEndCalledTimes, 1)
        let spanData = span.toSpanData()
        let event = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(1), attributes: [String: AttributeValue]())
        verifySpanData(spanData: spanData,
                       attributes: expectedAttributes,
                       events: [event],
                       links: [link],
                       spanName: spanNewName,
                       startTime: startTime,
                       endTime: testClock.now,
                       status: .ok,
                       hasEnded: true)
    }

    func testToSpanData_RootSpan() {
        let span = createTestRootSpan()
        spanDoWork(span: span, status: .unset)
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.parentSpanId, nil)
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
        XCTAssertEqual(span.toSpanData().status, Status.unset)
        span.status = .ok
        XCTAssertEqual(span.toSpanData().status, Status.ok)
        span.status = .error(description: "GenericError")
        XCTAssertTrue(span.toSpanData().status.isError)
        span.end()
        span.status = .ok
        XCTAssertTrue(span.toSpanData().status.isError)
    }

    func testGetSpanKind() {
        let span = createTestSpan(kind: .server)
        XCTAssertEqual(span.toSpanData().kind, SpanKind.server)
        span.end()
    }

    func testGetInstrumentationScopeInfo() {
        let span = createTestSpan(kind: .client)
        XCTAssertEqual(span.instrumentationScopeInfo, instrumentationScopeInfo)
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
        let elapsedTime1 = testClock.now.timeIntervalSince(startTime)
        XCTAssertEqual(span.latency, elapsedTime1)
        testClock.advanceMillis(millisPerSecond)
        let elapsedTime2 = testClock.now.timeIntervalSince(startTime)
        XCTAssertEqual(span.latency, elapsedTime2)
        span.end()
    }

    func testGetLatencyNs_EndedSpan() {
        let span = createTestSpan(kind: .internal)
        testClock.advanceMillis(millisPerSecond)
        span.end()
        let elapsedTime = testClock.now.timeIntervalSince(startTime)
        XCTAssertEqual(span.latency, elapsedTime)
        testClock.advanceMillis(millisPerSecond)
        XCTAssertEqual(span.latency, elapsedTime)
    }

    func testSetAttribute() {
        let span = createTestRootSpan()
        span.setAttribute(key: "StringKey", value: "StringVal")
        span.setAttribute(key: "EmptyStringkey", value: "")
        span.setAttribute(key: "NilAttributeValue", value: nil)
        span.setAttribute(key: "EmptyStringAttributeValue", value: AttributeValue.string(""))
        span.setAttribute(key: "LongKey", value: 1000)
        span.setAttribute(key: "DoubleKey", value: 10.0)
        span.setAttribute(key: "BooleanKey", value: false)
        span.setAttribute(key: "ArrayStringKey", value: AttributeValue.array(AttributeArray(values:[.string("StringVal"), .string(""), .string("StringVal2")])))
        span.setAttribute(key: "ArrayLongKey", value: AttributeValue.array(AttributeArray(values:[.int(1), .int(2), .int(3), .int(4), .int(5)])))
        span.setAttribute(key: "ArrayDoubleKey", value: AttributeValue.array(AttributeArray(values:[.double(0.1),.double(2.3), .double(4.5), .double(6.7), .double(8.9)])))
        span.setAttribute(key: "ArrayBoolKey", value: AttributeValue.array(AttributeArray(values:[.bool(true), .bool(false), .bool(false), .bool(true)])))
        span.setAttribute(key: "EmptyArrayStringKey", value: AttributeValue.array(AttributeArray.empty))
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, 11)
        XCTAssert({
            if case let AttributeValue.array(array) = spanData.attributes["ArrayStringKey"]! {
              return array.values.count == 3
            }
            return false
        }())
        XCTAssert({
            if case let AttributeValue.array(array) = spanData.attributes["ArrayLongKey"]! {
                return array.values.count == 5
            }
            return false
        }())
        XCTAssert({
            if case let AttributeValue.array(array) = spanData.attributes["ArrayDoubleKey"]! {
                return array.values.count == 5
            }
            return false
        }())
        XCTAssert({
            if case let AttributeValue.array(array) = spanData.attributes["ArrayBoolKey"]! {
                return array.values.count == 4
            }
            return false
        }())
    }

    func testAddEvent() {
        let span = createTestRootSpan()
        span.addEvent(name: "event1")
        span.addEvent(name: "event2", attributes: attributes)
        span.end()
        let spanData = span.toSpanData()
        XCTAssertEqual(spanData.events.count, 2)
    }

    func testWithInitializedAttributes() {
        let attributes = ["hello": AttributeValue.string("world")]

        let span = createTestSpan(attributes: attributes)

        XCTAssertEqual(attributes.count, span.totalAttributeCount, "total attributes not counted properly")
        XCTAssertEqual(span.toSpanData().attributes.count, span.totalAttributeCount, "total attributes not counted properly")

    }

    func testRemovingAttributes() {
        let attributes = ["remove": AttributeValue.string("me")]
        let span = createTestSpan(attributes: attributes)
        span.setAttribute(key: "keep", value: "me")
        span.setAttribute(key: "remove", value: nil)
        XCTAssertEqual(1, span.totalAttributeCount, "total attributes not counted properly")
        XCTAssertEqual(span.toSpanData().attributes.count, span.totalAttributeCount, "total attributes not counted properly")
    }

    func testDroppingAttributes() {
        let maxNumberOfAttributes = 8
        let spanLimits = SpanLimits().settingAttributeCountLimit(UInt(maxNumberOfAttributes))
        let span = createTestSpan(config: spanLimits)
        for i in 0 ..< 2 * maxNumberOfAttributes {
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(i))
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes)
        XCTAssertEqual(spanData.totalAttributeCount, 2 * maxNumberOfAttributes)
        span.end()
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes)
        XCTAssertEqual(spanData.totalAttributeCount, 2 * maxNumberOfAttributes)
    }

    func testDroppingAndAddingAttributes() {
        let maxNumberOfAttributes = 8
        let spanLimits = SpanLimits().settingAttributeCountLimit(UInt(maxNumberOfAttributes))
        let span = createTestSpan(config: spanLimits)
        for i in 0 ..< 2 * maxNumberOfAttributes {
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(i))
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes)
        XCTAssertEqual(spanData.totalAttributeCount, 2 * maxNumberOfAttributes)
        for i in 0 ..< maxNumberOfAttributes / 2 {
            let val = i + maxNumberOfAttributes * 3 / 2
            span.setAttribute(key: "MyStringAttributeKey\(i)", value: AttributeValue.int(val))
        }
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.attributes.count, maxNumberOfAttributes)
        // Test that we still have in the attributes map the latest attributeCountLimit / 2 entries.
        for i in 0 ..< maxNumberOfAttributes / 2 {
            let val = i + maxNumberOfAttributes * 3 / 2
            let expectedValue = AttributeValue.int(val)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i)"], expectedValue)
        }
        // Test that we have the newest re-added initial entries.
        for i in maxNumberOfAttributes / 2 ..< maxNumberOfAttributes {
            let expectedValue = AttributeValue.int(i)
            XCTAssertEqual(spanData.attributes["MyStringAttributeKey\(i)"], expectedValue)
        }
        span.end()
    }

    func testDroppingEvents() {
        let maxNumberOfEvents = 8
        let spanLimits = SpanLimits().settingEventCountLimit(UInt(maxNumberOfEvents))
        let span = createTestSpan(config: spanLimits)
        for _ in 0 ..< 2 * maxNumberOfEvents {
            span.addEvent(name: "event2", attributes: [String: AttributeValue]())
            testClock.advanceMillis(millisPerSecond)
        }
        var spanData = span.toSpanData()
        XCTAssertEqual(spanData.events.count, maxNumberOfEvents) //
        for i in 0 ..< maxNumberOfEvents {
            let expectedEvent = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(TimeInterval(maxNumberOfEvents + i)), attributes: [String: AttributeValue]())
            XCTAssertEqual(spanData.events[i], expectedEvent)
            XCTAssertEqual(spanData.totalRecordedEvents, 2 * maxNumberOfEvents)
        }
        span.end()
        spanData = span.toSpanData()
        XCTAssertEqual(spanData.events.count, maxNumberOfEvents)
        for i in 0 ..< maxNumberOfEvents {
            let expectedEvent = SpanData.Event(name: "event2", timestamp: startTime.addingTimeInterval(TimeInterval(maxNumberOfEvents + i)), attributes: [String: AttributeValue]())
            XCTAssertEqual(spanData.events[i], expectedEvent)
        }
    }

    func testAsSpanData() {
        let name = "GreatSpan"
        let kind = SpanKind.server
        let traceId = idGenerator.generateTraceId()
        let spanId = idGenerator.generateSpanId()
        let parentSpanId = idGenerator.generateSpanId()
        let spanLimits = SpanLimits()
        let spanProcessor = NoopSpanProcessor()
        let clock = TestClock()
        var attribute = [String: AttributeValue]()
        attribute["foo"] = AttributeValue.string("bar")
        let resource = Resource(attributes: attributes)
        let attributes = TestUtils.generateRandomAttributes()
        var attributesWithCapacity = AttributesDictionary(capacity: 32)
        attributesWithCapacity.updateValues(attributes: attributes)

        let event1Attributes = TestUtils.generateRandomAttributes()
        let event2Attributes = TestUtils.generateRandomAttributes()
        let context = SpanContext.create(traceId: traceId,
                                         spanId: spanId,
                                         traceFlags: TraceFlags(),
                                         traceState: TraceState())
        let parentContext = SpanContext.create(traceId: traceId,
                                               spanId: parentSpanId,
                                               traceFlags: TraceFlags(),
                                               traceState: TraceState())
        let link1 = SpanData.Link(context: context, attributes: TestUtils.generateRandomAttributes())
        let links = [link1]

        let readableSpan = RecordEventsReadableSpan.startSpan(context: context,
                                                              name: name,
                                                              instrumentationScopeInfo: instrumentationScopeInfo,
                                                              kind: kind,
                                                              parentContext: parentContext,
                                                              hasRemoteParent: false,
                                                              spanLimits: spanLimits,
                                                              spanProcessor: spanProcessor,
                                                              clock: clock,
                                                              resource: resource,
                                                              attributes: attributesWithCapacity,
                                                              links: links,
                                                              totalRecordedLinks: 1,
                                                              startTime: Date(timeIntervalSinceReferenceDate: 0))
        let startTime = clock.now
        clock.advanceMillis(4)
        let firstEventTimeNanos = clock.now
        readableSpan.addEvent(name: "event1", attributes: event1Attributes)
        clock.advanceMillis(6)
        let secondEventTimeNanos = clock.now
        readableSpan.addEvent(name: "event2", attributes: event2Attributes)

        clock.advanceMillis(100)
        readableSpan.end()
        let endTime = clock.now
        let event1 = SpanData.Event(name: "event1", timestamp: firstEventTimeNanos, attributes: event1Attributes)
        let event2 = SpanData.Event(name: "event2", timestamp: secondEventTimeNanos, attributes: event2Attributes)
        let events = [event1, event2]
        let expected = SpanData(traceId: traceId,
                                spanId: spanId,
                                traceFlags: TraceFlags(),
                                traceState: TraceState(),
                                parentSpanId: parentSpanId,
                                resource: resource,
                                instrumentationScope: instrumentationScopeInfo,
                                name: name,
                                kind: kind,
                                startTime: startTime,
                                attributes: attributes,
                                events: events,
                                links: links,
                                status: .unset,
                                endTime: endTime,
                                hasRemoteParent: false,
                                hasEnded: true,
                                totalRecordedEvents: 2,
                                totalRecordedLinks: links.count,
                                totalAttributeCount: 1)

        let result = readableSpan.toSpanData()
        XCTAssertEqual(expected, result)
    }

    private func createTestRootSpan() -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: SpanLimits(), parentContext: nil, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(attributes: [String: AttributeValue]) -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: SpanLimits(), parentContext: nil, attributes: attributes)
    }

    private func createTestSpan(kind: SpanKind) -> RecordEventsReadableSpan {
        let parentContext = SpanContext.create(traceId: traceId,
                                               spanId: parentSpanId,
                                               traceFlags: TraceFlags(),
                                               traceState: TraceState())
        return createTestSpan(kind: kind, config: SpanLimits(), parentContext: parentContext, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(config: SpanLimits) -> RecordEventsReadableSpan {
        return createTestSpan(kind: .internal, config: config, parentContext: nil, attributes: [String: AttributeValue]())
    }

    private func createTestSpan(kind: SpanKind, config: SpanLimits, parentContext: SpanContext?, attributes: [String: AttributeValue]) -> RecordEventsReadableSpan {
        var attributesWithCapacity = AttributesDictionary(capacity: config.attributeCountLimit)
        attributesWithCapacity.updateValues(attributes: attributes)

        let span = RecordEventsReadableSpan.startSpan(context: spanContext,
                                                      name: spanName,
                                                      instrumentationScopeInfo: instrumentationScopeInfo,
                                                      kind: kind,
                                                      parentContext: parentContext,
                                                      hasRemoteParent: true,
                                                      spanLimits: config,
                                                      spanProcessor: spanProcessor,
                                                      clock: testClock,
                                                      resource: resource,
                                                      attributes: attributesWithCapacity,
                                                      links: [link],
                                                      totalRecordedLinks: 1,
                                                      startTime: startTime)
        XCTAssertEqual(spanProcessor.onStartCalledTimes, 1)
        return span
    }

    private func spanDoWork(span: RecordEventsReadableSpan, status: Status) {
        span.setAttribute(key: "MySingleStringAttributeKey", value: AttributeValue.string("MySingleStringAttributeValue"))

        for attribute in attributes {
            span.setAttribute(key: attribute.key, value: attribute.value)
        }
        testClock.advanceMillis(millisPerSecond)
        span.addEvent(name: "event2", attributes: [String: AttributeValue]())
        testClock.advanceMillis(millisPerSecond)
        span.name = spanNewName
        span.status = status
    }

    private func verifySpanData(spanData: SpanData,
                                attributes: [String: AttributeValue],
                                events: [SpanData.Event],
                                links: [SpanData.Link], spanName: String,
                                startTime: Date,
                                endTime: Date,
                                status: Status,
                                hasEnded: Bool)
    {
        XCTAssertEqual(spanData.traceId, traceId)
        XCTAssertEqual(spanData.spanId, spanId)
        XCTAssertEqual(spanData.parentSpanId, parentSpanId)
        XCTAssertEqual(spanData.hasRemoteParent, expectedHasRemoteParent)
        XCTAssertEqual(spanData.traceState, TraceState())
        XCTAssertEqual(spanData.resource, resource)
        XCTAssertEqual(spanData.instrumentationScope, instrumentationScopeInfo)
        XCTAssertEqual(spanData.name, spanName)
        XCTAssertEqual(spanData.attributes, attributes)
        XCTAssertEqual(spanData.events, events)
        XCTAssert(spanData.links == links)
        XCTAssertEqual(spanData.startTime, startTime)
        XCTAssertEqual(spanData.endTime, endTime)
        XCTAssertEqual(spanData.status, status)
        XCTAssertEqual(spanData.hasEnded, hasEnded)
    }
}
