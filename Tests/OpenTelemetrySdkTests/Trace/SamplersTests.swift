/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class SamplerTests: XCTestCase {
  let spanName = "MySpanName"
  let spanKind = SpanKind.internal
  let numSamplesTries = 1000
  let idGenerator: IdGenerator = RandomIdGenerator()
  var traceId: TraceId!
  var spanId: SpanId!
  var parentSpanId: SpanId!
  let traceState = TraceState()
  var sampledSpanContext: SpanContext!
  var notSampledSpanContext: SpanContext!
  var sampledParentLink: SpanData.Link!

  override func setUp() {
    traceId = idGenerator.generateTraceId()
    spanId = idGenerator.generateSpanId()
    parentSpanId = idGenerator.generateSpanId()
    sampledSpanContext = SpanContext.create(traceId: traceId, spanId: parentSpanId, traceFlags: TraceFlags().settingIsSampled(true), traceState: traceState)
    notSampledSpanContext = SpanContext.create(traceId: traceId, spanId: parentSpanId, traceFlags: TraceFlags(), traceState: traceState)
    sampledParentLink = SpanData.Link(context: sampledSpanContext)
  }

  func testAlwaysOnSampler_AlwaysReturnTrue() {
    XCTAssertTrue(Samplers.alwaysOn.shouldSample(parentContext: sampledSpanContext,
                                                 traceId: traceId,
                                                 name: spanName,
                                                 kind: spanKind,
                                                 attributes: [String: AttributeValue](),
                                                 parentLinks: [SpanData.Link]())
        .isSampled)
  }

  func testAlwaysOffSampler_AlwaysReturnFalse() {
    XCTAssertFalse(Samplers.alwaysOff.shouldSample(parentContext: sampledSpanContext,
                                                   traceId: traceId,
                                                   name: spanName,
                                                   kind: spanKind,
                                                   attributes: [String: AttributeValue](),
                                                   parentLinks: [SpanData.Link]())
        .isSampled)
  }

  func testTraceIdRatioBasedSampler_AlwaysSample() {
    let sampler = TraceIdRatioBased(ratio: 1)
    XCTAssertEqual(sampler.idUpperBound, UInt.max)
  }

  func testTraceIdRatioBasedSampler_NeverSample() {
    let sampler = TraceIdRatioBased(ratio: 0)
    XCTAssertEqual(sampler.idUpperBound, UInt.min)
  }

  func testTraceIdRatioBasedSampler_outOfRangeHighProbability() {
    let sampler = TraceIdRatioBased(ratio: 1.01)
    XCTAssertEqual(sampler.idUpperBound, UInt.max)
  }

  func testTraceIdRatioBasedSampler_outOfRangeLowProbability() {
    let sampler = TraceIdRatioBased(ratio: -0.0001)
    XCTAssertEqual(sampler.idUpperBound, UInt.min)
  }

  func testTraceIdRatioBasedSampler_getDescription() {
    XCTAssertEqual(TraceIdRatioBased(ratio: 0.5).description, String(format: "TraceIdRatioBased{%.6f}", 0.5))
  }

  func testTraceIdRatioBasedSampler_ToString() {
    XCTAssertTrue(TraceIdRatioBased(ratio: 0.5).description.contains("0.5"))
  }

  // Applies the given sampler to NUM_SAMPLE_TRIES random traceId/spanId pairs.
  private func assertSamplerSamplesWithProbability(sampler: Sampler, parent: SpanContext, parentLinks: [SpanData.Link], probability: Double) {
    var count = 0 // Count of spans with sampling enabled
    for _ in 0 ..< numSamplesTries {
      if sampler.shouldSample(parentContext: parent,
                              traceId: TraceId.random(),
                              name: spanName,
                              kind: spanKind,
                              attributes: [String: AttributeValue](),
                              parentLinks: parentLinks).isSampled {
        count += 1
      }
    }
    let proportionSampled = Double(count) / Double(numSamplesTries)
    // Allow for a large amount of slop (+/- 10%) in number of sampled traces, to avoid flakiness.
    XCTAssertTrue(proportionSampled < probability + 0.1 && proportionSampled > probability - 0.1)
  }

  func testProbabilitySampler_DifferentProbabilities_NotSampledParent() {
    let fiftyPercentSample = TraceIdRatioBased(ratio: 0.5)
    assertSamplerSamplesWithProbability(sampler: fiftyPercentSample, parent: notSampledSpanContext, parentLinks: [SpanData.Link](), probability: 0.5)
    let twentyPercentSample = TraceIdRatioBased(ratio: 0.2)
    assertSamplerSamplesWithProbability(sampler: twentyPercentSample, parent: notSampledSpanContext, parentLinks: [SpanData.Link](), probability: 0.2)
    let twoThirdsSample = TraceIdRatioBased(ratio: 2.0 / 3.0)
    assertSamplerSamplesWithProbability(sampler: twoThirdsSample, parent: notSampledSpanContext, parentLinks: [SpanData.Link](), probability: 2.0 / 3.0)
  }

  func testProbabilitySampler_DifferentProbabilities_SampledParent() {
    let fiftyPercentSample = TraceIdRatioBased(ratio: 0.5)
    assertSamplerSamplesWithProbability(sampler: fiftyPercentSample, parent: sampledSpanContext, parentLinks: [SpanData.Link](), probability: 1.0)
    let twentyPercentSample = TraceIdRatioBased(ratio: 0.2)
    assertSamplerSamplesWithProbability(sampler: twentyPercentSample, parent: sampledSpanContext, parentLinks: [SpanData.Link](), probability: 1.0)
    let twoThirdsSample = TraceIdRatioBased(ratio: 2.0 / 3.0)
    assertSamplerSamplesWithProbability(sampler: twoThirdsSample, parent: sampledSpanContext, parentLinks: [SpanData.Link](), probability: 1.0)
  }

  func testProbabilitySampler_DifferentProbabilities_SampledParentLink() {
    let fiftyPercentSample = TraceIdRatioBased(ratio: 0.5)
    assertSamplerSamplesWithProbability(sampler: fiftyPercentSample, parent: notSampledSpanContext, parentLinks: [sampledParentLink], probability: 1.0)
    let twentyPercentSample = TraceIdRatioBased(ratio: 0.2)
    assertSamplerSamplesWithProbability(sampler: twentyPercentSample, parent: notSampledSpanContext, parentLinks: [sampledParentLink], probability: 1.0)
    let twoThirdsSample = TraceIdRatioBased(ratio: 2.0 / 3.0)
    assertSamplerSamplesWithProbability(sampler: twoThirdsSample, parent: notSampledSpanContext, parentLinks: [sampledParentLink], probability: 1.0)
  }

  func testProbabilitySampler_SampleBasedOnTraceId() {
    let defaultProbability = TraceIdRatioBased(ratio: 0.0001)
    // This traceId will not be sampled by the ProbabilitySampler because the first 8 bytes as long
    // is not less than probability * Long.MAX_VALUE;
    let notSampledtraceId = TraceId(fromBytes: [0, 0, 0, 0, 0, 0, 0, 0, 0x8F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])

    let decision1 = defaultProbability.shouldSample(parentContext: nil,
                                                    traceId: notSampledtraceId,
                                                    name: spanName,
                                                    kind: spanKind,
                                                    attributes: [String: AttributeValue](),
                                                    parentLinks: [SpanData.Link]())
    XCTAssertFalse(decision1.isSampled)
    XCTAssertEqual(decision1.attributes.count, 0)
    // This traceId will be sampled by the ProbabilitySampler because the first 8 bytes as long
    // is less than probability * Long.MAX_VALUE;
    let sampledtraceId = TraceId(fromBytes: [0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0])
    let decision2 = defaultProbability.shouldSample(parentContext: nil,
                                                    traceId: sampledtraceId,
                                                    name: spanName,
                                                    kind: spanKind,
                                                    attributes: [String: AttributeValue](),
                                                    parentLinks: [SpanData.Link]())
    XCTAssertTrue(decision2.isSampled)
    XCTAssertEqual(decision2.attributes.count, 0)
  }
}
