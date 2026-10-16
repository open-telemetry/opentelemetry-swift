/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

class NoopSpanProcessorTest: XCTestCase {
  let readableSpan = ReadableSpanMock()

  func testNoCrash() {
    let noopSpanProcessor = NoopSpanProcessor()
    noopSpanProcessor.onStart(parentContext: nil, span: readableSpan)
    XCTAssertFalse(noopSpanProcessor.isStartRequired)
    noopSpanProcessor.onEnd(span: readableSpan)
    XCTAssertFalse(noopSpanProcessor.isEndRequired)
    noopSpanProcessor.forceFlush()
    noopSpanProcessor.shutdown()
  }
}
