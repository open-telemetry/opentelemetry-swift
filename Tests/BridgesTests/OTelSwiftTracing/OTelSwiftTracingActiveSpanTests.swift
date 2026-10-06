/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import Instrumentation
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import OTelSwiftTracing
import Tracing
import XCTest

final class OTelSwiftTracingActiveSpanTests: XCTestCase {
  func testLookupThroughTracerProtocolAndGlobalTracer() throws {
    let tracer = makeTracer()
    XCTAssertNil(tracer.activeSpan(identifiedBy: .topLevel))
    let previousInstrument = InstrumentationSystem.instrument
    InstrumentationSystem.bootstrapInternal(tracer)
    defer { InstrumentationSystem.bootstrapInternal(previousInstrument) }
    let protocolTracer: any Tracing.Tracer = tracer

    try tracer.withSpan("active") { span in
      let context = try XCTUnwrap(ServiceContext.current)
      XCTAssertTrue(tracer.activeSpan(identifiedBy: span.context) === span)
      XCTAssertTrue(protocolTracer.activeSpan(identifiedBy: context) as? OTelSpan === span)
      XCTAssertTrue(InstrumentationSystem.tracer.activeSpan(identifiedBy: context) as? OTelSpan === span)
    }
  }

  func testNestedSpansResolveTheirOwnContexts() throws {
    let tracer = makeTracer()
    try tracer.withSpan("parent") { parent in
      try tracer.withSpan("child") { child in
        let current = try XCTUnwrap(ServiceContext.current)
        XCTAssertTrue(tracer.activeSpan(identifiedBy: current) === child)
        XCTAssertTrue(tracer.activeSpan(identifiedBy: parent.context) === parent)
      }
      let restored = try XCTUnwrap(ServiceContext.current)
      XCTAssertTrue(tracer.activeSpan(identifiedBy: restored) === parent)
    }
  }

  func testLookupFollowsAsyncContextPropagation() async throws {
    let tracer = makeTracer()
    try await tracer.withSpan("async") { span in
      await Task.yield()
      let context = try XCTUnwrap(ServiceContext.current)
      XCTAssertTrue(tracer.activeSpan(identifiedBy: context) === span)
      let inherited = await Task {
        ServiceContext.current.flatMap { tracer.activeSpan(identifiedBy: $0) }
      }.value
      XCTAssertTrue(inherited === span)
      let detached = await Task.detached {
        ServiceContext.current.flatMap { tracer.activeSpan(identifiedBy: $0) }
      }.value
      XCTAssertNil(detached)
    }
  }

  func testRegistryRetainsSpanUntilEnd() throws {
    let tracer = makeTracer()
    var span: OTelSpan? = tracer.startSpan("retained")
    weak var retainedSpan: OTelSpan?
    retainedSpan = span
    let context = span!.context
    span = nil
    XCTAssertNotNil(retainedSpan)
    var active: OTelSpan? = try XCTUnwrap(tracer.activeSpan(identifiedBy: context))
    XCTAssertTrue(active === retainedSpan)
    active!.end()
    active!.end()
    XCTAssertNil(tracer.activeSpan(identifiedBy: context))
    active = nil
    XCTAssertNil(retainedSpan)
    XCTAssertNotNil(context.otelSpanContext)
  }

  func testReleasingTracerReleasesUnendedSpan() {
    let processor = CapturingSpanProcessor()
    let provider = TracerProviderSdk(spanProcessors: [processor])
    defer { processor.span?.end() }
    var tracer: OTelTracer? = OTelTracer(tracerProvider: provider)
    var span: OTelSpan? = tracer!.startSpan("abandoned")
    weak var retainedSpan: OTelSpan?
    retainedSpan = span
    let context = span!.context
    span = nil
    XCTAssertNotNil(retainedSpan)
    tracer = nil
    XCTAssertNil(retainedSpan)
    XCTAssertNotNil(context.otelSpanContext)
  }

  func testCopiedTracerSharesRegistryButIndependentTracerDoesNot() {
    let tracer = makeTracer()
    let copy = tracer
    let independent = makeTracer()
    let span = tracer.startSpan("owned")
    defer { span.end() }
    XCTAssertTrue(copy.activeSpan(identifiedBy: span.context) === span)
    XCTAssertNil(independent.activeSpan(identifiedBy: span.context))
  }

  func testNativeEndIsDetectedAndReleasesWrapperOnLookup() throws {
    let processor = CapturingSpanProcessor()
    let provider = TracerProviderSdk(spanProcessors: [processor])
    let tracer = OTelTracer(tracerProvider: provider)
    var span: OTelSpan? = tracer.startSpan("native-end")
    weak var retainedSpan: OTelSpan?
    retainedSpan = span
    let context = span!.context
    let native = try XCTUnwrap(processor.span)
    span = nil
    XCTAssertNotNil(retainedSpan)
    native.end()
    XCTAssertFalse(native.isRecording)
    XCTAssertNotNil(retainedSpan)
    XCTAssertNil(tracer.activeSpan(identifiedBy: context))
    XCTAssertNil(retainedSpan)
  }

  func testNonRecordingSpanIsNotRetained() {
    let tracer = makeTracer(sampler: Samplers.alwaysOff)
    var span: OTelSpan? = tracer.startSpan("dropped")
    weak var releasedSpan: OTelSpan?
    releasedSpan = span
    let context = span!.context
    XCTAssertFalse(span!.isRecording)
    span = nil
    XCTAssertNil(releasedSpan)
    XCTAssertNil(tracer.activeSpan(identifiedBy: context))
  }

  func testExtractedContextDoesNotResolveLocalSpan() {
    let tracer = makeTracer()
    let span = tracer.startSpan("local")
    defer { span.end() }
    var carrier: [String: String] = [:]
    tracer.inject(span.context, into: &carrier, using: DictionaryInjector())
    var extracted = ServiceContext.topLevel
    tracer.extract(carrier, into: &extracted, using: DictionaryExtractor())
    XCTAssertEqual(extracted.otelSpanContext?.spanId, span.context.otelSpanContext?.spanId)
    XCTAssertNil(tracer.activeSpan(identifiedBy: extracted))
    extracted = span.context
    tracer.extract(carrier, into: &extracted, using: DictionaryExtractor())
    XCTAssertNil(tracer.activeSpan(identifiedBy: extracted))
    XCTAssertTrue(tracer.activeSpan(identifiedBy: span.context) === span)
  }

  private func makeTracer(sampler: Sampler = Samplers.alwaysOn) -> OTelTracer {
    let provider = TracerProviderSdk(sampler: sampler)
    return OTelTracer(tracerProvider: provider, propagator: W3CTraceContextPropagator())
  }
}

private struct DictionaryInjector: Injector {
  func inject(_ value: String, forKey key: String, into carrier: inout [String: String]) {
    carrier[key] = value
  }
}

private struct DictionaryExtractor: Extractor {
  func extract(key: String, from carrier: [String: String]) -> String? {
    carrier[key]
  }
}

private final class CapturingSpanProcessor: SpanProcessor {
  var span: ReadableSpan?
  let isStartRequired = true
  let isEndRequired = false

  func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: ReadableSpan) {
    self.span = span
  }

  func onEnd(span: ReadableSpan) {}
  func shutdown(explicitTimeout: TimeInterval?) {}
  func forceFlush(timeout: TimeInterval?) {}
}
