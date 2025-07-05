/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class SpanSdkTest: XCTestCase {
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
    span.setAttribute(key: "ArrayStringKey", value: AttributeValue.array(AttributeArray(values: [.string("StringVal"), .string(""), .string("StringVal2")])))
    span.setAttribute(key: "ArrayLongKey", value: AttributeValue.array(AttributeArray(values: [.int(1), .int(2), .int(3), .int(4), .int(5)])))
    span.setAttribute(key: "ArrayDoubleKey", value: AttributeValue.array(AttributeArray(values: [.double(0.1), .double(2.3), .double(4.5), .double(6.7), .double(8.9)])))
    span.setAttribute(key: "ArrayBoolKey", value: AttributeValue.array(AttributeArray(values: [.bool(true), .bool(false), .bool(false), .bool(true)])))
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

  func testSetAttributes() {
    let span = createTestRootSpan()

    let attributes: [String: AttributeValue] = ["hello": .string("world"),
                                                "count": .int(2)]

    let attributes2: [String: AttributeValue] = ["fiz": .string("buzz"),
                                                 "pi": .double(3.14)]
    span.setAttributes(attributes)

    XCTAssertEqual(attributes, span.getAttributes())

    span.setAttributes(attributes2)

    var attributes3 : [String: AttributeValue] = [:]

    attributes3.merge(attributes) { (_, new) in new }
    attributes3.merge(attributes2) { (_, new) in new }

    XCTAssertEqual(attributes3, span.getAttributes())
  }


  func testGetAttributes() {
    let span = createTestRootSpan()
    
    let attributes: [String: AttributeValue] = ["hello": .string("world"),
                                                "count": .int(2)]
    
    span.setAttributes(attributes)
    
    var spanAttributes = span.getAttributes()

    spanAttributes["newAttribute"] = .string("oops!")

    XCTAssertNotEqual(spanAttributes, span.getAttributes())

  }

  func testAddEvent() {
    let span = createTestRootSpan()
    span.addEvent(name: "event1")
    span.addEvent(name: "event2", attributes: attributes)
    span.end()
    let spanData = span.toSpanData()
    XCTAssertEqual(spanData.events.count, 2)
  }

  #if !os(Linux)
    func testRecordExceptionWithStackTrace() throws {
      final class TestException: NSException {
        override var callStackSymbols: [String] {
          [
            "test-stack-entry-1",
            "test-stack-entry-2",
            "test-stack-entry-3"
          ]
        }
      }

      let span = createTestRootSpan()
      let exception = TestException(name: .genericException, reason: "test reason")
      span.recordException(exception)
      span.end()
      let spanData = span.toSpanData()
      XCTAssertEqual(spanData.events.count, 1)

      let spanException = exception as SpanException
      let exceptionMessage = try XCTUnwrap(spanException.message)
      let exceptionStackTrace = try XCTUnwrap(spanException.stackTrace)

      let exceptionEvent = try XCTUnwrap(spanData.events.first)
      let exceptionAttributes = exceptionEvent.attributes
      XCTAssertEqual(exceptionEvent.name, SemanticAttributes.exception.rawValue)
      XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(spanException.type))
      XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionMessage.rawValue], .string(exceptionMessage))
      XCTAssertNil(exceptionAttributes[SemanticAttributes.exceptionEscaped.rawValue])
      XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionStacktrace.rawValue], .string(exceptionStackTrace.joined(separator: "\n")))
    }

    func testRecordExceptionWithoutStackTrace() throws {
      let span = createTestRootSpan()
      let exception = NSException(name: .genericException, reason: "test reason")
      span.recordException(exception)
      span.end()
      let spanData = span.toSpanData()
      XCTAssertEqual(spanData.events.count, 1)

      let spanException = exception as SpanException
      let exceptionMessage = try XCTUnwrap(spanException.message)

      let exceptionEvent = try XCTUnwrap(spanData.events.first)
      let exceptionAttributes = exceptionEvent.attributes
      XCTAssertEqual(exceptionEvent.name, SemanticAttributes.exception.rawValue)
      XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(spanException.type))
      XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionMessage.rawValue], .string(exceptionMessage))
      XCTAssertNil(exceptionAttributes[SemanticAttributes.exceptionEscaped.rawValue])
      XCTAssertNil(exceptionAttributes[SemanticAttributes.exceptionStacktrace.rawValue])
    }

    func testRecordMultipleExceptions() throws {
      let span = createTestRootSpan()

      let firstException = NSException(name: .genericException, reason: "test reason")
      span.recordException(firstException)

      let secondException = NSError(domain: "test", code: 0)
      span.recordException(secondException)

      span.end()
      let spanData = span.toSpanData()
      XCTAssertEqual(spanData.events.count, 2)

      let firstSpanException = firstException as SpanException
      let secondSpanException = secondException as SpanException
      let firstExceptionAttributes = try XCTUnwrap(spanData.events.first?.attributes)
      let secondExceptionAttributes = try XCTUnwrap(spanData.events.last?.attributes)
      XCTAssertEqual(firstExceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(firstSpanException.type))
      XCTAssertEqual(secondExceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(secondSpanException.type))
    }
  #endif

  func testExceptionAttributesOverwriteAdditionalAttributes() throws {
    let span = createTestRootSpan()
    let exception = NSError(domain: "test error", code: 5)
    span.recordException(exception,
                         attributes: [
                           SemanticAttributes.exceptionMessage.rawValue: .string("another, different reason"),
                           "This-Key-Should-Not-Get-Overwritten": .string("original-value")
                         ])
    span.end()
    let spanData = span.toSpanData()
    XCTAssertEqual(spanData.events.count, 1)

    let spanException = exception as SpanException
    let exceptionMessage = try XCTUnwrap(spanException.message)

    let exceptionEvent = try XCTUnwrap(spanData.events.first)
    let exceptionAttributes = exceptionEvent.attributes

    // Custom value specified for `SemanticAttributes.exceptionMessage`,
    // but overwritten by the value out of the provided exception.
    XCTAssertEqual(exceptionAttributes.count, 3)
    XCTAssertNotEqual(exceptionMessage, "another, different reason")
    XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionMessage.rawValue], .string(exceptionMessage))
    XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(spanException.type))
    XCTAssertEqual(exceptionAttributes["This-Key-Should-Not-Get-Overwritten"], .string("original-value"))
  }

  func testDroppingEventAttributesWhenRecordingException() throws {
    let maxNumberOfAttributes = 3
    let spanLimits = SpanLimits().settingAttributePerEventCountLimit(UInt(maxNumberOfAttributes))
    let span = createTestSpan(config: spanLimits)
    let exception = NSError(domain: "test error", code: 0)
    let attributes: [String: AttributeValue] = [
      "Additional-Key-1": .string("Additional-Key-1"),
      "Additional-Key-2": .string("Value 2"),
      "Additional-Key-3": .string("Value 3")
    ]

    span.recordException(exception, attributes: attributes)
    span.end()

    let spanData = span.toSpanData()
    XCTAssertEqual(spanData.events.count, 1)

    let spanException = exception as SpanException
    let exceptionMessage = try XCTUnwrap(spanException.message)

    let exceptionEvent = try XCTUnwrap(spanData.events.first)
    let exceptionAttributes = exceptionEvent.attributes

    // Only 3 attributes per event. Exception events have priority (total of 2), so 1 slot left for additional attributes.
    // Attributes are added in the order in which their keys appear in the original Dictionary, and are also removed
    // using the same sequence when overflowing. However, since the order of key-value pairs in a dictionary is
    // unpredictable, there are no guarantees to how they are ingested in the first place.
    //
    // With that in mind, this test ensures that out of the 3 attributes in the resulting dictionary, 2 are expected due to
    // prioritization and the remaining 1 matches an entry from the additional attributes. We just can't be sure
    // which of those entries it will be.
    XCTAssertEqual(exceptionAttributes.count, 3)
    XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionMessage.rawValue], .string(exceptionMessage))
    XCTAssertEqual(exceptionAttributes[SemanticAttributes.exceptionType.rawValue], .string(spanException.type))

    let remainingExceptionAttributeKeys = exceptionAttributes.keys.filter { key in
      key != SemanticAttributes.exceptionMessage.rawValue &&
        key != SemanticAttributes.exceptionType.rawValue
    }

    XCTAssertEqual(remainingExceptionAttributeKeys.count, 1)
    let remainingKey = try XCTUnwrap(remainingExceptionAttributeKeys.first)
    XCTAssertNotNil(attributes[remainingKey])
    XCTAssertEqual(attributes[remainingKey], exceptionAttributes[remainingKey])
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

  func testAttributesValueLength() {
    let maxValueLength = 8
    let spanLimits = SpanLimits().settingAttributeValueLengthLimit(UInt(maxValueLength))
    let span = createTestSpan(config: spanLimits)
    span.setAttribute(key: "max_value_length", value: .string("this is a big text that is longer than \(maxValueLength) characters"))
    span.end()
    let spanData = span.toSpanData()
    if case let .string(value) = spanData.attributes["max_value_length"] {
      XCTAssertEqual(span.maxValueLengthPerSpanAttribute, maxValueLength)
      XCTAssertEqual(value, "this is ")
    } else {
      XCTFail()
    }
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

  func testAddingEventsAboveLimitShouldntBeAllowed() {
    let maxNumberOfEvents = 8
    let spanLimits = SpanLimits().settingEventCountLimit(UInt(maxNumberOfEvents))
    let span = createTestSpan(config: spanLimits)

    for _ in 0 ..< 2 * maxNumberOfEvents {
      span.addEvent(name: "event2", attributes: [String: AttributeValue]())
      testClock.advanceMillis(millisPerSecond)
    }

    var spanData = span.toSpanData()

    XCTAssertEqual(spanData.events.count, maxNumberOfEvents)
    for i in 0 ..< maxNumberOfEvents {
      let expectedEvent = SpanData.Event(
        name: "event2",
        timestamp: startTime.addingTimeInterval(TimeInterval(i)),
        attributes: [String: AttributeValue]()
      )
      XCTAssertEqual(spanData.events[i], expectedEvent)
      XCTAssertEqual(spanData.totalRecordedEvents, 2 * maxNumberOfEvents)
    }

    span.end()
    spanData = span.toSpanData()

    XCTAssertEqual(spanData.events.count, maxNumberOfEvents)
    for i in 0 ..< maxNumberOfEvents {
      let expectedEvent = SpanData.Event(
        name: "event2",
        timestamp: startTime.addingTimeInterval(TimeInterval(i)),
        attributes: [String: AttributeValue]()
      )
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

    let readableSpan = SpanSdk.startSpan(context: context,
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

    clock.advanceMillis(15)
    let exceptionTimeNanos = clock.now
    let exception = NSError(domain: "test", code: 0)
    readableSpan.recordException(NSError(domain: "test", code: 0))

    clock.advanceMillis(100)
    readableSpan.end()
    let endTime = clock.now
    let event1 = SpanData.Event(name: "event1", timestamp: firstEventTimeNanos, attributes: event1Attributes)
    let event2 = SpanData.Event(name: "event2", timestamp: secondEventTimeNanos, attributes: event2Attributes)
    let exceptionEvent = SpanData.Event(name: SemanticAttributes.exception.rawValue,
                                        timestamp: exceptionTimeNanos,
                                        attributes: [
                                          SemanticAttributes.exceptionType.rawValue: .string(exception.type),
                                          SemanticAttributes.exceptionMessage.rawValue: .string(exception.message!)
                                        ])
    let events = [event1, event2, exceptionEvent]
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
                            totalRecordedEvents: events.count,
                            totalRecordedLinks: links.count,
                            totalAttributeCount: 1)

    let result = readableSpan.toSpanData()
    XCTAssertEqual(expected, result)
  }

  private func createTestRootSpan() -> SpanSdk {
    return createTestSpan(kind: .internal, config: SpanLimits(), parentContext: nil, attributes: [String: AttributeValue]())
  }

  private func createTestSpan(attributes: [String: AttributeValue]) -> SpanSdk {
    return createTestSpan(kind: .internal, config: SpanLimits(), parentContext: nil, attributes: attributes)
  }

  private func createTestSpan(kind: SpanKind) -> SpanSdk {
    let parentContext = SpanContext.create(traceId: traceId,
                                           spanId: parentSpanId,
                                           traceFlags: TraceFlags(),
                                           traceState: TraceState())
    return createTestSpan(kind: kind, config: SpanLimits(), parentContext: parentContext, attributes: [String: AttributeValue]())
  }

  private func createTestSpan(config: SpanLimits) -> SpanSdk {
    return createTestSpan(kind: .internal, config: config, parentContext: nil, attributes: [String: AttributeValue]())
  }

  private func createTestSpan(kind: SpanKind, config: SpanLimits, parentContext: SpanContext?, attributes: [String: AttributeValue]) -> SpanSdk {
    var attributesWithCapacity = AttributesDictionary(capacity: config.attributeCountLimit)
    attributesWithCapacity.updateValues(attributes: attributes)

    let span = SpanSdk.startSpan(context: spanContext,
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

  private func spanDoWork(span: SpanSdk, status: Status) {
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
                              hasEnded: Bool) {
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
