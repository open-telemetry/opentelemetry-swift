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

class SpanBuilderSdkTest: XCTestCase {
    let spanName = "span_name"
    let sampledSpanContext = SpanContext.create(traceId: TraceId(idHi: 1000, idLo: 1000),
                                                spanId: SpanId(id: 3000),
                                                traceFlags: TraceFlags().settingIsSampled(true),
                                                traceState: TraceState())
    var tracerSdkFactory = TracerSdkRegistry()
    var tracerSdk: Tracer!

    override func setUp() {
        tracerSdk = tracerSdkFactory.get(instrumentationName: "SpanBuilderSdkTest")
    }

    func testAddLink() {
        // Verify methods do not crash.
        let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
        spanBuilder.addLink(SpanData.Link(context: DefaultSpan().context))
        spanBuilder.addLink(spanContext: DefaultSpan().context)
        spanBuilder.addLink(spanContext: DefaultSpan().context, attributes: [String: AttributeValue]())
        let span = spanBuilder.startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.toSpanData().links.count, 3)
        span.end()
    }

    func testTruncateLink() {
        let maxNumberOfLinks = 8
        let traceConfig = tracerSdkFactory.getActiveTraceConfig().settingMaxNumberOfLinks(maxNumberOfLinks)
        tracerSdkFactory.updateActiveTraceConfig(traceConfig)
        // Verify methods do not crash.
        let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
        for _ in 0 ..< 2 * maxNumberOfLinks {
            spanBuilder.addLink(spanContext: sampledSpanContext)
        }
        let span = spanBuilder.startSpan() as! RecordEventsReadableSpan
        let spanData = span.toSpanData()
        let links = spanData.links
        XCTAssertEqual(links.count, maxNumberOfLinks)
        for i in 0 ..< maxNumberOfLinks {
            XCTAssert(span.links[i] == SpanData.Link(context: sampledSpanContext))
            XCTAssertEqual(spanData.totalRecordedLinks, 2 * maxNumberOfLinks)
        }
        span.end()
        tracerSdkFactory.updateActiveTraceConfig(TraceConfig())
    }

    func testSetAttribute() {
        let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
        spanBuilder.setAttribute(key: "string", value: "value")
        spanBuilder.setAttribute(key: "long", value: 12345)
        spanBuilder.setAttribute(key: "double", value: 0.12345)
        spanBuilder.setAttribute(key: "boolean", value: true)
        spanBuilder.setAttribute(key: "stringAttribute", value: AttributeValue.string("attrvalue"))

        let span = spanBuilder.startSpan() as! RecordEventsReadableSpan
        let attrs = span.toSpanData().attributes
        XCTAssertEqual(attrs.count, 5)
        XCTAssertEqual(attrs["string"], AttributeValue.string("value"))
        XCTAssertEqual(attrs["long"], AttributeValue.int(12345))
        XCTAssertEqual(attrs["double"], AttributeValue.double(0.12345))
        XCTAssertEqual(attrs["boolean"], AttributeValue.bool(true))
        XCTAssertEqual(attrs["stringAttribute"], AttributeValue.string("attrvalue"))
        span.end()
    }

    func testSetAttribute_nilStringValue() {
        let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
        spanBuilder.setAttribute(key: "emptyString", value: "")
        spanBuilder.setAttribute(key: "nilStringAttributeValue", value: AttributeValue.string(nil))
        spanBuilder.setAttribute(key: "emptyStringAttributeValue", value: AttributeValue.string(""))

        let span = spanBuilder.startSpan() as! RecordEventsReadableSpan
        XCTAssertTrue(span.toSpanData().attributes.isEmpty)
        span.end()
    }

    func testDroppingAttributes() {
        let maxNumberOfAttrs = 8
        let traceConfig = tracerSdkFactory.getActiveTraceConfig().settingMaxNumberOfAttributes(maxNumberOfAttrs)
        tracerSdkFactory.updateActiveTraceConfig(traceConfig)
        let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
        for i in 0 ..< 2 * maxNumberOfAttrs {
            spanBuilder.setAttribute(key: "key\(i)", value: i)
        }
        let span = spanBuilder.startSpan() as! RecordEventsReadableSpan
        let attrs = span.toSpanData().attributes
        XCTAssertEqual(attrs.count, maxNumberOfAttrs)
        for i in 0 ..< maxNumberOfAttrs {
            XCTAssertEqual(attrs["key\(i + maxNumberOfAttrs)"], AttributeValue.int(i + maxNumberOfAttrs))
        }
        span.end()
        tracerSdkFactory.updateActiveTraceConfig(TraceConfig())
    }

    func testRecordEvents_default() {
        let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! RecordEventsReadableSpan
        XCTAssertTrue(span.isRecordingEvents)
        span.end()
    }

    func testKind_default() {
        let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.kind, SpanKind.internal)
        span.end()
    }

    func testKind() {
        let span = tracerSdk.spanBuilder(spanName: spanName).setSpanKind(spanKind: .consumer).startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.kind, SpanKind.consumer)
    }

    func testSampler() {
        let span = TestUtils.startSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                                  tracer: tracerSdk, spanName: spanName,
                                                  sampler: Samplers.alwaysOff).startSpan()
        XCTAssertFalse(span.context.traceFlags.sampled)
        span.end()
    }

    static let samplerAttributeName = "sampler-attribute"

    func testSampler_decisionAttributes() {
        class TestSampler: Sampler {
            var decision: Decision
            func shouldSample(parentContext: SpanContext?,
                              traceId: TraceId,
                              spanId: SpanId,
                              name: String,
                              parentLinks: [Link]) -> Decision {
                return decision
            }

            var description: String { return "TestSampler" }
            init(decision: Decision) { self.decision = decision }
        }

        class TestDecision: Decision {
            var isSampled: Bool {
                return true
            }

            var attributes: [String: AttributeValue] {
                return [SpanBuilderSdkTest.samplerAttributeName: AttributeValue.string("bar")]
            }
        }

        let decision = TestDecision()
        let sampler = TestSampler(decision: decision)
        let span = TestUtils.startSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                                  tracer: tracerSdk,
                                                  spanName: spanName,
                                                  sampler: sampler,
                                                  attributes: [SpanBuilderSdkTest.samplerAttributeName: AttributeValue.string("none")])
            .startSpan() as! RecordEventsReadableSpan
        XCTAssertTrue(span.context.traceFlags.sampled)
        XCTAssertTrue(span.toSpanData().attributes.keys.contains(SpanBuilderSdkTest.samplerAttributeName))
        span.end()
    }

    func testSampledViaParentLinks() {
        let span = TestUtils.startSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                                  tracer: tracerSdk, spanName: spanName,
                                                  sampler: Samplers.probability(probability: 0.0))
            .addLink(spanContext: sampledSpanContext)
            .startSpan()
        XCTAssertTrue(span.context.traceFlags.sampled)
        span.end()
    }

    func testNoParent() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        var scope = tracerSdk.withSpan(parent)
        let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().startSpan()
        XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
        let spanNoParent = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent).setNoParent().startSpan()
        XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
        spanNoParent.end()
        span.end()
        scope.close()
        parent.end()
    }

    func testNoParent_override() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent).startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.context.traceId, parent.context.traceId)
        XCTAssertEqual(span.parentSpanId, parent.context.spanId)
        let span2 = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent.context).startSpan()
        XCTAssertEqual(span2.context.traceId, parent.context.traceId)
        span2.end()
        span.end()
        parent.end()
    }

    func testOverrideNoParent_remoteParent() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent.context).startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.context.traceId, parent.context.traceId)
        XCTAssertEqual(span.parentSpanId, parent.context.spanId)
        span.end()
        parent.end()
    }

    func testParentCurrentSpan() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        var scope = tracerSdk.withSpan(parent)
        let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! RecordEventsReadableSpan
        XCTAssertEqual(span.context.traceId, parent.context.traceId)
        XCTAssertEqual(span.parentSpanId, parent.context.spanId)
        span.end()
        scope.close()
        parent.end()
    }

    func testParent_invalidContext() {
        let parent = DefaultSpan()
        let span = tracerSdk.spanBuilder(spanName: spanName).setParent(parent.context).startSpan() as! RecordEventsReadableSpan
        XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
        XCTAssertNil(span.parentSpanId)
        span.end()
    }

    func testParent_timestampConverter() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        let span = tracerSdk.spanBuilder(spanName: spanName).setParent(parent).startSpan() as! RecordEventsReadableSpan
        XCTAssert(span.clock === (parent as! RecordEventsReadableSpan).clock)
        parent.end()
    }

    func testParentCurrentSpan_timestampConverter() {
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        var scope = tracerSdk.withSpan(parent)
        let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! RecordEventsReadableSpan
        XCTAssert(span.clock === (parent as! RecordEventsReadableSpan).clock)
        scope.close()
        parent.end()
    }
}
