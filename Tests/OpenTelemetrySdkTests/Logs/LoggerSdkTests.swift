//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import XCTest
import OpenTelemetryTestUtils
@testable import OpenTelemetrySdk

public class LoggerSdkTests: OpenTelemetryContextTestCase {
  func testEventBuilder() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())
    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "test"),
                           eventDomain: "Test")

    logger.eventBuilder(name: "myEvent").setData(["test": AttributeValue("data")]).emit()

    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.eventName, "myEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.name"]?.description, "myEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.domain"]?.description, "Test")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.data"]?.description, "[\"test\": data]")
  }

  func testEventBuilderNoDomain() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())
    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "test"),
                           eventDomain: nil)

    logger.eventBuilder(name: "myEvent").emit()

    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertNotNil(processor.onEmitCalledLogRecord)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.eventName, "myEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.name"]?.description, "myEvent")
    XCTAssertNil(processor.onEmitCalledLogRecord?.attributes["event.domain"])
  }

  func testNewEventDomain() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())
    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "test"),
                           eventDomain: "OldDomain")

    logger.eventBuilder(name: "myEvent").emit()

    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.eventName, "myEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.name"]?.description, "myEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.domain"]?.description, "OldDomain")

    let newLogger = logger.withEventDomain(domain: "MyDomain")

    newLogger.eventBuilder(name: "MyEvent").emit()
    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertNotNil(processor.onEmitCalledLogRecord)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.eventName, "MyEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.name"]?.description, "MyEvent")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.attributes["event.domain"]?.description, "MyDomain")
  }

  func testLogRecordBuilderSetEventName() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())
    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "test"),
                           eventDomain: nil)

    logger.logRecordBuilder()
      .setEventName("session.start")
      .setBody(AttributeValue.string("foo bar"))
      .emit()

    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.eventName, "session.start")
    XCTAssertEqual(processor.onEmitCalledLogRecord?.body?.description, "foo bar")
  }

  func testWithoutTraceContext() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())
    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "test"), eventDomain: nil)

    let loggerWithoutTrace = logger.withoutTraceContext()
    
    XCTAssertFalse(logger === loggerWithoutTrace)
    
    loggerWithoutTrace.logRecordBuilder()
      .setBody(AttributeValue.string("test message"))
      .emit()
    
    XCTAssertTrue(processor.onEmitCalled)
    XCTAssertNotNil(processor.onEmitCalledLogRecord)
  }

  func testContextPropogation() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())

    let context = SpanContext.create(traceId: TraceId(idHi: 0, idLo: 16), spanId: SpanId(id: 8), traceFlags: TraceFlags(),
                                     traceState: TraceState())
    let span = SpanSdk.startSpan(context: context,
                                                  name: "Test",
                                                  instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
                                                  kind: .client,
                                                  parentContext: nil,
                                                  hasRemoteParent: false,
                                                  spanLimits: SpanLimits(),
                                                  spanProcessor: NoopSpanProcessor(),
                                                  clock: MillisClock(),
                                                  resource: Resource(),
                                                  attributes: AttributesDictionary(capacity: 1),
                                                  links: [SpanData.Link](),
                                                  totalRecordedLinks: 1,
                                                  startTime: Date())

    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "TestName"),
                           eventDomain: "TestDomain")

    OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
      let specialContext = SpanContext.create(traceId: TraceId(idHi: 0, idLo: 0), spanId: SpanId(id: 0), traceFlags: TraceFlags(),
                                              traceState: TraceState())

      logger.eventBuilder(name: "MyEvent").setSpanContext(specialContext).emit()

      XCTAssertNotNil(processor.onEmitCalledLogRecord?.spanContext)

      XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.spanId.rawValue, 0)
      XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.traceId.idLo, 0)

      logger.eventBuilder(name: "MyEvent").emit()

      XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.spanId.rawValue, 8)
      XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.traceId.idLo, 16)
    }
  }
}

final class LoggerSdkTestsImperative: OpenTelemetryContextTestCase {
  override var contextManagers: [any ContextManager] {
    Self.imperativeContextManagers()
  }

  func testContextPropogation() {
    let processor = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor], clock: MillisClock())

    let context = SpanContext.create(traceId: TraceId(idHi: 0, idLo: 16), spanId: SpanId(id: 8), traceFlags: TraceFlags(),
                                     traceState: TraceState())
    let span = SpanSdk.startSpan(context: context,
                                                  name: "Test",
                                                  instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
                                                  kind: .client,
                                                  parentContext: nil,
                                                  hasRemoteParent: false,
                                                  spanLimits: SpanLimits(),
                                                  spanProcessor: NoopSpanProcessor(),
                                                  clock: MillisClock(),
                                                  resource: Resource(),
                                                  attributes: AttributesDictionary(capacity: 1),
                                                  links: [SpanData.Link](),
                                                  totalRecordedLinks: 1,
                                                  startTime: Date())

    let logger = LoggerSdk(sharedState: sharedState, instrumentationScope: InstrumentationScopeInfo(name: "TestName"),
                           eventDomain: "TestDomain")
    OpenTelemetry.instance.contextProvider.setActiveSpan(span)

    let specialContext = SpanContext.create(traceId: TraceId(idHi: 0, idLo: 0), spanId: SpanId(id: 0), traceFlags: TraceFlags(),
                                            traceState: TraceState())

    logger.eventBuilder(name: "MyEvent").setSpanContext(specialContext).emit()

    XCTAssertNotNil(processor.onEmitCalledLogRecord?.spanContext)

    XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.spanId.rawValue, 0)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.traceId.idLo, 0)

    logger.eventBuilder(name: "MyEvent").emit()

    XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.spanId.rawValue, 8)
    XCTAssertEqual(processor.onEmitCalledLogRecord?.spanContext?.traceId.idLo, 16)

    OpenTelemetry.instance.contextProvider.removeContextForSpan(span)
  }
}
