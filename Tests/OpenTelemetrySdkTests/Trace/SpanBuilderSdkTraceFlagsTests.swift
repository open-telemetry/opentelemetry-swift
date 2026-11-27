/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class SpanBuilderSdkTraceFlagsTests: XCTestCase {
  private let remoteParentRandom = SpanContext.createFromRemoteParent(
    traceId: TraceId(idHi: 1, idLo: 2),
    spanId: SpanId(id: 3),
    traceFlags: TraceFlags().settingIsSampled(true).settingIsRandom(true),
    traceState: TraceState()
  )

  private let remoteParentNotRandom = SpanContext.createFromRemoteParent(
    traceId: TraceId(idHi: 1, idLo: 2),
    spanId: SpanId(id: 3),
    traceFlags: TraceFlags().settingIsSampled(true),
    traceState: TraceState()
  )

  private func makeTracer(idGenerator: IdGenerator = RandomIdGenerator(),
                          sampler: Sampler = Samplers.alwaysOn) -> Tracer {
    TracerProviderBuilder()
      .with(idGenerator: idGenerator)
      .with(sampler: sampler)
      .build()
      .get(instrumentationName: "trace-flags-test")
  }

  func testRandomIdGeneratorReportsRandomTraceIds() {
    XCTAssertTrue(RandomIdGenerator().generatesRandomTraceIds)
  }

  func testCustomIdGeneratorDefaultsToNonRandom() {
    XCTAssertFalse(LegacyIdGenerator().generatesRandomTraceIds)
  }

  func testRootSpanSetsRandomFlagWithRandomIdGenerator() {
    let span = makeTracer().spanBuilder(spanName: "root").startSpan()

    XCTAssertTrue(span.context.traceFlags.sampled)
    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }

  func testRootSpanOmitsRandomFlagForCustomIdGenerator() {
    let span = makeTracer(idGenerator: LegacyIdGenerator())
      .spanBuilder(spanName: "root").startSpan()

    XCTAssertTrue(span.context.traceFlags.sampled)
    XCTAssertFalse(span.context.traceFlags.random)
    span.end()
  }

  func testRootSpanHonoursRandomCapableCustomIdGenerator() {
    let span = makeTracer(idGenerator: RandomCapableIdGenerator())
      .spanBuilder(spanName: "root").startSpan()

    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }

  func testDroppedRootSpanStillSetsRandomFlag() {
    let span = makeTracer(sampler: Samplers.alwaysOff)
      .spanBuilder(spanName: "dropped-root").startSpan()

    XCTAssertFalse(span.context.traceFlags.sampled)
    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }

  func testChildSpanInheritsRandomFlagFromRemoteParent() {
    let span = makeTracer().spanBuilder(spanName: "child")
      .setParent(remoteParentRandom)
      .startSpan()

    XCTAssertTrue(span.context.traceFlags.sampled)
    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }

  func testChildSpanDoesNotAddRandomFlagForRemoteParentWithoutIt() {
    let span = makeTracer().spanBuilder(spanName: "child")
      .setParent(remoteParentNotRandom)
      .startSpan()

    XCTAssertTrue(span.context.traceFlags.sampled)
    XCTAssertFalse(span.context.traceFlags.random)
    span.end()
  }

  func testDroppedChildSpanPreservesRandomFlagFromRemoteParent() {
    let span = makeTracer(sampler: Samplers.alwaysOff).spanBuilder(spanName: "dropped-child")
      .setParent(remoteParentRandom)
      .startSpan()

    XCTAssertFalse(span.context.traceFlags.sampled)
    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }

  func testLocalChildSpanInheritsRandomFlagFromParent() {
    let tracer = makeTracer()
    let parent = tracer.spanBuilder(spanName: "parent").startSpan()
    let child = tracer.spanBuilder(spanName: "child").setParent(parent).startSpan()

    XCTAssertTrue(child.context.traceFlags.random)
    child.end()
    parent.end()
  }

  func testGeneratorReplacedDuringTraceIdGenerationKeepsRandomFlagConsistent() {
    let first = SwappingIdGenerator(generatesRandomTraceIds: true)
    let provider = TracerProviderBuilder()
      .with(idGenerator: first)
      .with(sampler: Samplers.alwaysOn)
      .build()
    first.onGenerateTraceId = {
      provider.updateActiveIdGenerator(SwappingIdGenerator(generatesRandomTraceIds: false))
    }

    let span = provider.get(instrumentationName: "trace-flags-test")
      .spanBuilder(spanName: "root").startSpan()

    XCTAssertTrue(span.context.traceFlags.random)
    span.end()
  }
}

/// A generator written before `generatesRandomTraceIds` existed. It intentionally
/// omits the property so the test exercises the protocol extension's default.
private struct LegacyIdGenerator: IdGenerator {
  func generateSpanId() -> SpanId {
    SpanId(id: 10)
  }

  func generateTraceId() -> TraceId {
    TraceId(idHi: 20, idLo: 30)
  }
}

private struct RandomCapableIdGenerator: IdGenerator {
  var generatesRandomTraceIds = true

  func generateSpanId() -> SpanId {
    SpanId(id: 10)
  }

  func generateTraceId() -> TraceId {
    TraceId(idHi: 20, idLo: 30)
  }
}

private final class SwappingIdGenerator: IdGenerator {
  let generatesRandomTraceIds: Bool
  var onGenerateTraceId: (() -> Void)?

  init(generatesRandomTraceIds: Bool) {
    self.generatesRandomTraceIds = generatesRandomTraceIds
  }

  func generateSpanId() -> SpanId {
    SpanId(id: 10)
  }

  func generateTraceId() -> TraceId {
    onGenerateTraceId?()
    return TraceId(idHi: 20, idLo: 30)
  }
}
