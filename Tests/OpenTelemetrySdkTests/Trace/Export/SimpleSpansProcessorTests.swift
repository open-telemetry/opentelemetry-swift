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

class SimpleSpansProcessorTests: XCTestCase {
    let maxScheduleDelayMillis = 500
    let spanName = "MySpanName"
    var readableSpan = ReadableSpanMock()
    var spanExporter = SpanExporterMock()
    var tracerSdkFactory = TracerSdkRegistry()
    var tracer: Tracer!
    let waitingSpanExporter = WaitingSpanExporter()
    let sampledSpanContext = SpanContext.create(traceId: TraceId(), spanId: SpanId(), traceFlags: TraceFlags().settingIsSampled(true), traceState: TraceState())
    let notSampledSpanContext = SpanContext.create(traceId: TraceId(), spanId: SpanId(), traceFlags: TraceFlags(), traceState: TraceState())

    var simpleSampledSpansProcessor: SimpleSpanProcessor!

    override func setUp() {
        tracer = tracerSdkFactory.get(instrumentationName: "SimpleSpanProcessor")
        simpleSampledSpansProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
    }

    func testOnStartSync() {
        simpleSampledSpansProcessor.onStart(span: readableSpan)
        XCTAssertTrue(spanExporter.exportCalledTimes == 0 && spanExporter.shutdownCalledTimes == 0)
    }

    func testOnEndSync_SampledSpan() {
        let spanData = TestUtils.makeBasicSpan()
        readableSpan.forcedReturnSpanContext = sampledSpanContext
        readableSpan.forcedReturnSpanData = spanData
        simpleSampledSpansProcessor.onEnd(span: readableSpan)
        XCTAssertEqual(spanExporter.exportCalledTimes, 1)
    }

    func testOnEndSync_NotSampledSpan() {
        readableSpan.forcedReturnSpanContext = notSampledSpanContext
        simpleSampledSpansProcessor.onEnd(span: readableSpan)
        XCTAssertTrue(spanExporter.exportCalledTimes == 0 && spanExporter.shutdownCalledTimes == 0)
    }

    func testOnEndSync_OnlySampled_NotSampledSpan() {
        readableSpan.forcedReturnSpanContext = notSampledSpanContext
        readableSpan.forcedReturnSpanData = TestUtils.makeBasicSpan()
        var simpleSpansProcessor = SimpleSpanProcessor(spanExporter: spanExporter).reportingOnlySampled(sampled: true)
        simpleSpansProcessor.onEnd(span: readableSpan)
        XCTAssertTrue(spanExporter.exportCalledTimes == 0 && spanExporter.shutdownCalledTimes == 0)
    }

    func testOnEndSync_OnlySampled_SampledSpan() {
        readableSpan.forcedReturnSpanContext = sampledSpanContext
        readableSpan.forcedReturnSpanData = TestUtils.makeBasicSpan()
        var simpleSpansProcessor = SimpleSpanProcessor(spanExporter: spanExporter).reportingOnlySampled(sampled: true)
        simpleSpansProcessor.onEnd(span: readableSpan)
        XCTAssertEqual(spanExporter.exportCalledTimes, 1)
    }

    func testTracerSdk_NotSampled_Span() {
        // TODO: Needs BatchSpansProcessor
//        tracer.addSpanProcessor(BatchSpanProcessor(spanExporter: waitingSpanExporter).setScheduleDelayMillis(maxScheduleDelayMillis))
//        tracer.spanBuilder(spanName: spanName).setSampler(sampler: Samplers.neverSample).startSpan().end()
//        tracer.spanBuilder(spanName: spanName).setSampler(sampler: Samplers.neverSample).startSpan().end()
//        let span = tracer.spanBuilder(spanName: spanName).setSampler(sampler: Samplers.alwaysSample).startSpan()
//        span.end() //
//        // Spans are recorded and exported in the same order as they are ended, we test that a non
//        // sampled span is not exported by creating and ending a sampled span after a non sampled span
//        // and checking that the first exported span is the sampled span (the non sampled did not get
//        // exported).
//        let exported = waitingSpanExporter.waitForExport(1)
//        // Need to check this because otherwise the variable span1 is unused, other option is to not
//        // have a span1 variable.
//        XCTAssertEqual(exported, (span as! ReadableSpan).toSpanData())
    }

    func testTracerSdk_NotSampled_RecordingEventsSpan() {
        // TODO(bdrutu): Fix this when Sampler return RECORD option.
        /*
         tracer.addSpanProcessor(
             BatchSpansProcessor.newBuilder(waitingSpanExporter)
                 .setScheduleDelayMillis(MAX_SCHEDULE_DELAY_MILLIS)
                 .reportOnlySampled(false)
                 .build());

         io.opentelemetry.trace.Span span =
             tracer
                 .spanBuilder("FOO")
                 .setSampler(Samplers.neverSample())
                 .startSpan();
         span.end();

         List<SpanData> exported = waitingSpanExporter.waitForExport(1);
         assertThat(exported).containsExactly(((ReadableSpan) span).toSpanData());
         */
    }

    func testOnEndSync_ExporterReturnError() {
        let spanData = TestUtils.makeBasicSpan()
        readableSpan.forcedReturnSpanContext = sampledSpanContext
        readableSpan.forcedReturnSpanData = spanData
        simpleSampledSpansProcessor.onEnd(span: readableSpan)
        // Try again, now will no longer return error.
        simpleSampledSpansProcessor.onEnd(span: readableSpan)
        XCTAssertEqual(spanExporter.exportCalledTimes, 2)
    }

    func testShutdown() {
        simpleSampledSpansProcessor.shutdown()
        XCTAssertEqual(spanExporter.shutdownCalledTimes, 1)
    }
}
