//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest
import SharedTestUtils

class OtlpHttpLogRecordExporterTests: XCTestCase {
  var testServer: HttpTestServer!
  var spanContext: SpanContext!

  override func setUp() {
    testServer = HttpTestServer()
    XCTAssertNoThrow(try testServer.start())

    let spanId = SpanId.random()
    let traceId = TraceId.random()
    spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
  }

  override func tearDown() {
    XCTAssertNoThrow(try testServer.stop())
  }

  func testExport() {
    let testHeader = ("testHeader", "testValue")
    let testBody = AttributeValue.string("Helloworld" + String(Int.random(in: 1 ... 100)))
    let logRecord = ReadableLogRecord(resource: Resource(),
                                      instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                      timestamp: Date(),
                                      observedTimestamp: Date.distantPast,
                                      spanContext: spanContext,
                                      severity: .fatal,
                                      body: testBody,
                                      attributes: ["event.name": AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])

    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let config = OtlpConfiguration(compression: .none, headers: [testHeader])
    let exporter = OtlpHttpLogExporter(endpoint: endpoint, config: config)
    let _ = exporter.export(logRecords: [logRecord])

    // TODO: Use protobuf to verify that we have received the correct Log records
    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertTrue(head.headers.contains { header in
          header.name.lowercased() == testHeader.0.lowercased() && header.value == testHeader.1
      })
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })
    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      let bodyString = String(decoding: body, as: UTF8.self)
      XCTAssertTrue(bodyString.contains(testBody.description))
    })

    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  // TODO: for this and the other httpexporters, see if there is some way to really test this.  As writtne these tests
  // won't really do much as there are no pending spans
  func testFlush() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpLogExporter(endpoint: endpoint)
    XCTAssertEqual(ExportResult.success, exporter.flush())
  }

  func testForceFlush() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
    let exporter = OtlpHttpLogExporter(endpoint: endpoint)
    XCTAssertEqual(ExportResult.success, exporter.forceFlush())
  }
}
