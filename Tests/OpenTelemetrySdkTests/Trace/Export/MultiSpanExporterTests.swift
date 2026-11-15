/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class MultiSpanExporterTests: XCTestCase {
  var spanExporter1: SpanExporterMock!
  var spanExporter2: SpanExporterMock!
  var spanList: [SpanData]!

  override func setUp() {
    spanExporter1 = SpanExporterMock()
    spanExporter2 = SpanExporterMock()
    spanList = [TestUtils.makeBasicSpan()]
  }

  func testEmpty() {
    let multiSpanExporter = MultiSpanExporter(spanExporters: [SpanExporter]())
    _ = multiSpanExporter.export(spans: spanList)
    multiSpanExporter.shutdown()
  }

  func testOneSpanExporter() {
    let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1])
    spanExporter1.returnValue = .success
    XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.success)
    XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
    XCTAssertEqual(spanExporter1.exportCalledData, spanList)
    multiSpanExporter.shutdown()
    XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
  }

  func testTwoSpanExporter() {
    let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
    spanExporter1.returnValue = .success
    spanExporter2.returnValue = .success
    XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.success)
    XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
    XCTAssertEqual(spanExporter1.exportCalledData, spanList)
    XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
    XCTAssertEqual(spanExporter2.exportCalledData, spanList)
    multiSpanExporter.shutdown()
    XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
    XCTAssertEqual(spanExporter2.shutdownCalledTimes, 1)
  }

  func testTwoSpanExporter_OneReturnFailure() {
    let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
    spanExporter1.returnValue = .success
    spanExporter2.returnValue = .failure
    XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.failure)
    XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
    XCTAssertEqual(spanExporter1.exportCalledData, spanList)
    XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
    XCTAssertEqual(spanExporter2.exportCalledData, spanList)
  }
}
