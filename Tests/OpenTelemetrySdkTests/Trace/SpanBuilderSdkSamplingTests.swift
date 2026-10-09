/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import SharedTestUtils
import XCTest

class SpanBuilderSdkSamplingTestCase: OpenTelemetryContextTestCase {
  private(set) var idGenerator: SamplingTestIdGenerator!
  private(set) var processor: SpanProcessorMock!
  private(set) var exporter: SpanExporterMock!
  private(set) var provider: TracerProviderSdk!
  private(set) var tracer: Tracer!

  let remoteParent = SpanContext.createFromRemoteParent(
    traceId: TraceId(idHi: 1, idLo: 2),
    spanId: SpanId(id: 3),
    traceFlags: TraceFlags().settingIsSampled(true),
    traceState: TraceState().setting(key: "vendor", value: "parent")
  )

  override func setUp() {
    super.setUp()
    idGenerator = SamplingTestIdGenerator()
    processor = SpanProcessorMock()
    exporter = SpanExporterMock()
    provider = TracerProviderBuilder()
      .with(idGenerator: idGenerator)
      .with(sampler: Samplers.alwaysOn)
      .add(spanProcessor: processor)
      .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
      .build()
    tracer = provider.get(instrumentationName: "sampling-test")
  }

  override func tearDown() {
    provider.shutdown()
    super.tearDown()
  }

  func assertDropped(_ span: SpanBase, traceId: TraceId, traceState: TraceState = TraceState(),
                     file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(span.isRecording, file: file, line: line)
    XCTAssertTrue(span.context.isValid, file: file, line: line)
    XCTAssertFalse(span.context.isSampled, file: file, line: line)
    XCTAssertFalse(span.context.isRemote, file: file, line: line)
    XCTAssertEqual(span.context.traceId, traceId, file: file, line: line)
    XCTAssertEqual(span.context.spanId, idGenerator.spanId, file: file, line: line)
    XCTAssertEqual(span.context.traceState, traceState, file: file, line: line)
  }

  func assertProcessedSpans(_ count: Int, file: StaticString = #filePath, line: UInt = #line) {
    provider.forceFlush()
    XCTAssertEqual(processor.onStartCalledTimes, count, file: file, line: line)
    XCTAssertEqual(processor.onEndCalledTimes, count, file: file, line: line)
    XCTAssertEqual(exporter.exportCalledTimes, count, file: file, line: line)
  }
}

final class SpanBuilderSdkSamplingTests: SpanBuilderSdkSamplingTestCase {
  func testDroppedRootPreservesGeneratedContext() {
    provider.updateActiveSampler(Samplers.alwaysOff)
    let span = tracer.spanBuilder(spanName: "dropped-root").startSpan()
    assertDropped(span, traceId: idGenerator.traceId)
    span.setAttribute(key: "ignored", value: "value")
    span.addEvent(name: "ignored")
    span.end()
    span.end()
    assertProcessedSpans(0)
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }

  func testDroppedChildOfActiveSampledParent() {
    let parent = tracer.spanBuilder(spanName: "parent").setParent(remoteParent).startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      let span = tracer.spanBuilder(spanName: "dropped-child").startSpan()
      assertDropped(span, traceId: parent.context.traceId, traceState: parent.context.traceState)
      XCTAssertNotEqual(span.context.spanId, parent.context.spanId)
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
      span.end()
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
      XCTAssertTrue(parent.isRecording)
      XCTAssertTrue(parent.context.isSampled)
      XCTAssertEqual(processor.onStartCalledTimes, 1)
      XCTAssertEqual(processor.onEndCalledTimes, 0)
    }
    parent.end()
    assertProcessedSpans(1)
    XCTAssertEqual(exporter.exportCalledData?.first?.spanId, parent.context.spanId)
  }

  func testDroppedChildUsesExplicitLocalParentInsteadOfActiveSpan() {
    let parent = tracer.spanBuilder(spanName: "explicit-parent").setParent(remoteParent).startSpan()
    let active = tracer.spanBuilder(spanName: "unrelated-active").setNoParent().startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(active) {
      let span = tracer.spanBuilder(spanName: "dropped-child").setParent(parent).startSpan()
      assertDropped(span, traceId: parent.context.traceId, traceState: parent.context.traceState)
      XCTAssertNotEqual(span.context.spanId, parent.context.spanId)
      XCTAssertNotEqual(span.context.traceId, active.context.traceId)
      span.end()
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === active)
    }
    parent.end()
    active.end()
    assertProcessedSpans(2)
  }

  func testDroppedChildUsesExplicitRemoteParentInsteadOfActiveSpan() {
    let active = tracer.spanBuilder(spanName: "unrelated-active").setNoParent().startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(active) {
      let span = tracer.spanBuilder(spanName: "dropped-child").setParent(remoteParent).startSpan()
      assertDropped(span, traceId: remoteParent.traceId, traceState: remoteParent.traceState)
      XCTAssertNotEqual(span.context.spanId, remoteParent.spanId)
      XCTAssertNotEqual(span.context.traceId, active.context.traceId)
      span.end()
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === active)
    }
    active.end()
    assertProcessedSpans(1)
  }

  func testDroppedRootIgnoresActiveParent() {
    let parent = tracer.spanBuilder(spanName: "parent").setParent(remoteParent).startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      let span = tracer.spanBuilder(spanName: "dropped-root").setNoParent().startSpan()
      assertDropped(span, traceId: idGenerator.traceId)
      XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
      span.end()
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
    }
    parent.end()
    assertProcessedSpans(1)
  }

  func testDroppedSpanWithInvalidParentGeneratesRootContext() {
    let parent = tracer.spanBuilder(spanName: "parent").setParent(remoteParent).startSpan()
    let invalid = SpanContext.create(traceId: .invalid, spanId: .invalid,
                                     traceFlags: TraceFlags(), traceState: remoteParent.traceState)
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      let span = tracer.spanBuilder(spanName: "dropped-root").setParent(invalid).startSpan()
      assertDropped(span, traceId: idGenerator.traceId)
      XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
      span.end()
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
    }
    parent.end()
    assertProcessedSpans(1)
  }

  func testDroppedActiveSpanPropagatesUnsampledContextToDescendants() {
    let parent = tracer.spanBuilder(spanName: "parent").setParent(remoteParent).startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      tracer.spanBuilder(spanName: "dropped-child").withActiveSpan { span in
        assertDropped(span, traceId: parent.context.traceId, traceState: parent.context.traceState)
        XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
        var carrier = [String: String]()
        W3CTraceContextPropagator().inject(spanContext: span.context, carrier: &carrier,
                                           setter: SamplingTestSetter())
        XCTAssertEqual(carrier["traceparent"], "00-\(parent.context.traceId.hexString)-\(idGenerator.spanId.hexString)-00")
        XCTAssertEqual(carrier["tracestate"], "vendor=parent")

        provider.updateActiveSampler(Samplers.parentBased(root: Samplers.alwaysOn))
        let descendant = tracer.spanBuilder(spanName: "descendant").startSpan()
        assertDropped(descendant, traceId: span.context.traceId, traceState: span.context.traceState)
        XCTAssertNotEqual(descendant.context.spanId, span.context.spanId)
        descendant.end()
        XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
      }
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
      XCTAssertTrue(parent.isRecording)
    }
    parent.end()
    assertProcessedSpans(1)
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }

  func testDroppedActiveSpanRestoresParentAfterThrow() throws {
    enum TestError: Error { case expected }
    let parent = tracer.spanBuilder(spanName: "parent").startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)

    try OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      XCTAssertThrowsError(try tracer.spanBuilder(spanName: "dropped-child").withActiveSpan { span in
        assertDropped(span, traceId: parent.context.traceId)
        XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
        throw TestError.expected
      })
      XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
      XCTAssertTrue(parent.isRecording)
    }
    parent.end()
    assertProcessedSpans(1)
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }
}

final class SpanBuilderSdkSamplingImperativeTests: SpanBuilderSdkSamplingTestCase {
  override var contextManagers: [any ContextManager] {
    Self.imperativeContextManagers()
  }

  func testEndingDroppedActiveChildRestoresSampledParent() {
    let parent = tracer.spanBuilder(spanName: "parent").setActive(true).startSpan()
    provider.updateActiveSampler(Samplers.alwaysOff)
    let span = tracer.spanBuilder(spanName: "dropped-child").setActive(true).startSpan()
    assertDropped(span, traceId: parent.context.traceId)
    XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === span)
    span.end()
    XCTAssertTrue(OpenTelemetry.instance.contextProvider.activeSpan === parent)
    XCTAssertTrue(parent.isRecording)
    parent.end()
    assertProcessedSpans(1)
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }
}

final class SamplingTestIdGenerator: IdGenerator {
  private(set) var spanId = SpanId(id: 100)
  private(set) var traceId = TraceId(idHi: 100, idLo: 100)
  private var nextSpanId: UInt64 = 101
  private var nextTraceId: UInt64 = 101

  func generateSpanId() -> SpanId {
    spanId = SpanId(id: nextSpanId)
    nextSpanId += 1
    return spanId
  }

  func generateTraceId() -> TraceId {
    traceId = TraceId(idHi: 100, idLo: nextTraceId)
    nextTraceId += 1
    return traceId
  }
}

private struct SamplingTestSetter: Setter {
  func set(carrier: inout [String: String], key: String, value: String) {
    carrier[key] = value
  }
}
