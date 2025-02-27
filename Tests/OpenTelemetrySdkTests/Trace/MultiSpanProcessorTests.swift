/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MultiSpanProcessorTest: XCTestCase {
  let spanProcessor1 = SpanProcessorMock()
  let spanProcessor2 = SpanProcessorMock()
  let readableSpan = ReadableSpanMock()

  override func setUp() {
    spanProcessor1.isStartRequired = true
    spanProcessor1.isEndRequired = true
    spanProcessor2.isStartRequired = true
    spanProcessor2.isEndRequired = true
  }

  func testEmpty() {
    let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [SpanProcessor]())
    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    multiSpanProcessor.onEnd(span: readableSpan)
    multiSpanProcessor.shutdown(explicitTimeout: nil)
  }

  func testOneSpanProcessor() {
    let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1])
    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    XCTAssert(spanProcessor1.onStartCalledSpan === readableSpan)
    multiSpanProcessor.onEnd(span: readableSpan)
    XCTAssert(spanProcessor1.onEndCalledSpan === readableSpan)
    multiSpanProcessor.forceFlush()
    XCTAssertTrue(spanProcessor1.forceFlushCalled)
    multiSpanProcessor.shutdown(explicitTimeout: nil)
    XCTAssertTrue(spanProcessor1.shutdownCalled)
  }

  func testOneSpanProcessorNoRequeriments() {
    spanProcessor1.isStartRequired = false
    spanProcessor1.isEndRequired = false
    let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1])
    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)

    XCTAssertFalse(multiSpanProcessor.isStartRequired)
    XCTAssertFalse(multiSpanProcessor.isEndRequired)

    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    XCTAssertFalse(spanProcessor1.onStartCalled)
    multiSpanProcessor.onEnd(span: readableSpan)
    XCTAssertFalse(spanProcessor1.onEndCalled)
    multiSpanProcessor.forceFlush()
    XCTAssertTrue(spanProcessor1.forceFlushCalled)
    multiSpanProcessor.shutdown(explicitTimeout: nil)
    XCTAssertTrue(spanProcessor1.shutdownCalled)
  }

  func testTwoSpanProcessor() {
    let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1, spanProcessor2])

    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    XCTAssert(spanProcessor1.onStartCalledSpan === readableSpan)
    XCTAssert(spanProcessor2.onStartCalledSpan === readableSpan)

    multiSpanProcessor.onEnd(span: readableSpan)
    XCTAssert(spanProcessor1.onEndCalledSpan === readableSpan)
    XCTAssert(spanProcessor2.onEndCalledSpan === readableSpan)

    multiSpanProcessor.forceFlush()
    XCTAssertTrue(spanProcessor1.forceFlushCalled)
    XCTAssertTrue(spanProcessor2.forceFlushCalled)

    multiSpanProcessor.shutdown(explicitTimeout: nil)
    XCTAssertTrue(spanProcessor1.shutdownCalled)
    XCTAssertTrue(spanProcessor2.shutdownCalled)
  }

  func testTwoSpanProcessorDifferentRequirements() {
    spanProcessor1.isEndRequired = false
    spanProcessor2.isStartRequired = false

    let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1, spanProcessor2])

    XCTAssertTrue(multiSpanProcessor.isStartRequired)
    XCTAssertTrue(multiSpanProcessor.isEndRequired)

    multiSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    XCTAssert(spanProcessor1.onStartCalledSpan === readableSpan)
    XCTAssertFalse(spanProcessor2.onStartCalled)

    multiSpanProcessor.onEnd(span: readableSpan)
    XCTAssertFalse(spanProcessor1.onEndCalled)
    XCTAssert(spanProcessor2.onEndCalledSpan === readableSpan)

    multiSpanProcessor.forceFlush()
    XCTAssertTrue(spanProcessor1.forceFlushCalled)
    XCTAssertTrue(spanProcessor2.forceFlushCalled)

    multiSpanProcessor.shutdown()
    XCTAssertTrue(spanProcessor1.shutdownCalled)
    XCTAssertTrue(spanProcessor2.shutdownCalled)
  }
}
