/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class BatchSpansProcessorTests: XCTestCase {
  let spanName1 = "MySpanName/1"
  let spanName2 = "MySpanName/2"
  let maxScheduleDelay = 0.5
  let tracerSdkFactory = TracerProviderSdk()
  var tracer: Tracer!
  let blockingSpanExporter = BlockingSpanExporter()
  var mockServiceHandler = SpanExporterMock()
  
  override func setUp() {
    tracer = tracerSdkFactory.get(instrumentationName: "BatchSpansProcessorTest")
  }
  
  override func tearDown() {
    tracerSdkFactory.shutdown()
  }
  
  @discardableResult private func createSampledEndedSpan(spanName: String) -> ReadableSpan {
    let span = TestUtils.createSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                               tracer: tracer,
                                               spanName: spanName,
                                               sampler: Samplers.alwaysOn)
      .startSpan() as! ReadableSpan
    span.end()
    return span
  }
  
  private func createNotSampledEndedSpan(spanName: String) {
    TestUtils.createSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                    tracer: tracer,
                                    spanName: spanName,
                                    sampler: Samplers.alwaysOff)
    .startSpan()
    .end()
  }
  
  func testStartEndRequirements() {
    let spansProcessor = BatchSpanProcessor(spanExporter: WaitingSpanExporter(numberToWaitFor: 0))
    XCTAssertFalse(spansProcessor.isStartRequired)
    XCTAssertTrue(spansProcessor.isEndRequired)
  }
  
  func testExportDifferentSampledSpans() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 2)
    
    tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: waitingSpanExporter, scheduleDelay: maxScheduleDelay))
    let span1 = createSampledEndedSpan(spanName: spanName1)
    let span2 = createSampledEndedSpan(spanName: spanName2)
    let exported = waitingSpanExporter.waitForExport()
    
    XCTAssertEqual(exported, [span1.toSpanData(), span2.toSpanData()])
  }
  
  func testExportMoreSpansThanTheBufferSize() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 6)
    
    tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: waitingSpanExporter, scheduleDelay: maxScheduleDelay, maxQueueSize: 6, maxExportBatchSize: 2))
    
    let span1 = createSampledEndedSpan(spanName: spanName1)
    let span2 = createSampledEndedSpan(spanName: spanName1)
    let span3 = createSampledEndedSpan(spanName: spanName1)
    let span4 = createSampledEndedSpan(spanName: spanName1)
    let span5 = createSampledEndedSpan(spanName: spanName1)
    let span6 = createSampledEndedSpan(spanName: spanName1)
    let exported = waitingSpanExporter.waitForExport()
    XCTAssertEqual(exported, [span1.toSpanData(),
                              span2.toSpanData(),
                              span3.toSpanData(),
                              span4.toSpanData(),
                              span5.toSpanData(),
                              span6.toSpanData()])
  }
  
  func testForceExport() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 1)
    let batchSpansProcessor = BatchSpanProcessor(spanExporter: waitingSpanExporter, scheduleDelay: 10, maxQueueSize: 10000, maxExportBatchSize: 2000)
    tracerSdkFactory.addSpanProcessor(batchSpansProcessor)
    
    for _ in 0 ..< 100 {
      createSampledEndedSpan(spanName: "notExported")
    }
    batchSpansProcessor.forceFlush()
    let exported = waitingSpanExporter.waitForExport()
    XCTAssertEqual(exported?.count, 100)
  }
  
  func testExportSpansToMultipleServices() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 2)
    let waitingSpanExporter2 = WaitingSpanExporter(numberToWaitFor: 2)
    tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: MultiSpanExporter(spanExporters: [waitingSpanExporter, waitingSpanExporter2]), scheduleDelay: maxScheduleDelay))
    
    let span1 = createSampledEndedSpan(spanName: spanName1)
    let span2 = createSampledEndedSpan(spanName: spanName2)
    let exported1 = waitingSpanExporter.waitForExport()
    let exported2 = waitingSpanExporter2.waitForExport()
    XCTAssertEqual(exported1, [span1.toSpanData(), span2.toSpanData()])
    XCTAssertEqual(exported2, [span1.toSpanData(), span2.toSpanData()])
  }
  
  func testExportMoreSpansThanTheMaximumLimit() {
    let maxQueuedSpans = 8
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: maxQueuedSpans)
    
    tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: MultiSpanExporter(spanExporters: [waitingSpanExporter, blockingSpanExporter]), scheduleDelay:    maxScheduleDelay, maxQueueSize: maxQueuedSpans, maxExportBatchSize: maxQueuedSpans / 2))
    
    var spansToExport = [SpanData]()
    // Wait to block the worker thread in the BatchSampledSpansProcessor. This ensures that no items
    // can be removed from the queue. Need to add a span to trigger the export otherwise the
    // pipeline is never called.
    spansToExport.append(createSampledEndedSpan(spanName: "blocking_span").toSpanData())
    blockingSpanExporter.waitUntilIsBlocked()
    
    for i in 0 ..< maxQueuedSpans {
      // First export maxQueuedSpans, the worker thread is blocked so all items should be queued.
      spansToExport.append(createSampledEndedSpan(spanName: "span_1_\(i)").toSpanData())
    }
    
    // TODO: assertThat(spanExporter.getReferencedSpans()).isEqualTo(maxQueuedSpans);
    
    // Now we should start dropping.
    for i in 0 ..< 7 {
      createSampledEndedSpan(spanName: "span_2_\(i)")
      // TODO: assertThat(getDroppedSpans()).isEqualTo(i + 1);
    }
    
    // TODO: assertThat(getReferencedSpans()).isEqualTo(maxQueuedSpans);
    
    // Release the blocking exporter
    blockingSpanExporter.unblock()
    
    // While we wait for maxQueuedSpans we ensure that the queue is also empty after this.
    var exported = waitingSpanExporter.waitForExport()
    XCTAssertEqual(exported, spansToExport)
    
    exported?.removeAll()
    spansToExport.removeAll()
    
    // We cannot compare with maxReferencedSpans here because the worker thread may get
    // unscheduled immediately after exporting, but before updating the pushed spans, if that is
    // the case at most bufferSize spans will miss.
    // TODO: assertThat(getPushedSpans()).isAtLeast((long) maxQueuedSpans - maxBatchSize);
    
    for i in 0 ..< maxQueuedSpans {
      spansToExport.append(createSampledEndedSpan(spanName: "span_3_\(i)").toSpanData())
      // No more dropped spans.
      // TODO: assertThat(getDroppedSpans()).isEqualTo(7);
    }
    
    exported = waitingSpanExporter.waitForExport()
    XCTAssertEqual(exported, spansToExport)
  }
  
  func testExportNotSampledSpans() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 1)
    
    tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: waitingSpanExporter, scheduleDelay: maxScheduleDelay))
    
    createNotSampledEndedSpan(spanName: spanName1)
    createNotSampledEndedSpan(spanName: spanName2)
    let span2 = createSampledEndedSpan(spanName: spanName2)
    // Spans are recorded and exported in the same order as they are ended, we test that a non
    // sampled span is not exported by creating and ending a sampled span after a non sampled span
    // and checking that the first exported span is the sampled span (the non sampled did not get
    // exported).
    let exported = waitingSpanExporter.waitForExport()
    // Need to check this because otherwise the variable span1 is unused, other option is to not
    // have a span1 variable.
    XCTAssertEqual(exported, [span2.toSpanData()])
  }
  
  func testShutdownFlushes() {
    let waitingSpanExporter = WaitingSpanExporter(numberToWaitFor: 1)
    
    // Set the export delay to zero, for no timeout, in order to confirm the #flush() below works
      tracerSdkFactory.addSpanProcessor(BatchSpanProcessor(spanExporter: waitingSpanExporter, scheduleDelay: 0.1))
    
    let span2 = createSampledEndedSpan(spanName: spanName2)
    
    // Force a shutdown, without this, the waitForExport() call below would block indefinitely.
    tracerSdkFactory.shutdown()
    
    let exported = waitingSpanExporter.waitForExport()
    XCTAssertEqual(exported, [span2.toSpanData()])
    XCTAssertTrue(waitingSpanExporter.shutdownCalled)
  }
}

class BlockingSpanExporter: SpanExporter {
  let cond = NSCondition()
  
  enum State {
    case waitToBlock
    case blocked
    case unblocked
  }
  
  var state: State = .waitToBlock
  
  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    cond.lock()
    while state != .unblocked {
      state = .blocked
      // Some threads may wait for Blocked State.
      cond.broadcast()
      cond.wait()
    }
    cond.unlock()
    return .success
  }
  
  func waitUntilIsBlocked() {
    cond.lock()
    while state != .blocked {
      cond.wait()
    }
    cond.unlock()
  }
  
  func flush(explicitTimeout:TimeInterval?) -> SpanExporterResultCode {
    return .success
  }
  
  func shutdown(explicitTimeout: TimeInterval?) {}
  
  fileprivate func unblock() {
    cond.lock()
    state = .unblocked
    cond.unlock()
    cond.broadcast()
  }
}

class WaitingSpanExporter: SpanExporter {
  var spanDataList = [SpanData]()
  let cond = NSCondition()
  let numberToWaitFor: Int
  var shutdownCalled = false
  
  init(numberToWaitFor: Int) {
    self.numberToWaitFor = numberToWaitFor
  }
  
  func waitForExport() -> [SpanData]? {
    var ret: [SpanData]
    cond.lock()
    defer { cond.unlock() }
    
    while spanDataList.count < numberToWaitFor {
      cond.wait()
    }
    ret = spanDataList
    spanDataList.removeAll()
    
    return ret
  }
  
  func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    cond.lock()
    spanDataList.append(contentsOf: spans)
    cond.unlock()
    cond.broadcast()
    return .success
  }
  
  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }
  
  func shutdown(explicitTimeout: TimeInterval?) {
    shutdownCalled = true
  }
}
