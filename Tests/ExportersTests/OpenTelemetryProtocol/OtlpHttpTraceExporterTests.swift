//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Logging
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest
import SharedTestUtils

class OtlpHttpTraceExporterTests: XCTestCase {
  var testServer: HttpTestServer!

  override func setUp() {
    testServer = HttpTestServer()
    XCTAssertNoThrow(try testServer.start())
  }

  override func tearDown() {
    XCTAssertNoThrow(try testServer.stop())
  }

  // This is a somewhat hacky solution to verifying that the spans got across correctly.  It simply looks for the metric
  // description strings (which is why I made them unique) in the body returned by testServer.receiveBodyAndVerify().
  // It should ideally turn that body into [SpanData] using protobuf and then confirm content
  func testExport() {
    let testHeader = ("testHeader", "testValue")
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)/v1/traces")!
    let config = OtlpConfiguration(compression: .none, headers: [testHeader])
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint, config: config)

    var spans: [SpanData] = []
    let endpointName1 = "/api/foo" + String(Int.random(in: 1 ... 100))
    let endpointName2 = "/api/bar" + String(Int.random(in: 100 ... 500))
    spans.append(generateFakeSpan(endpointName: endpointName1))
    spans.append(generateFakeSpan(endpointName: endpointName2))
    let _ = exporter.export(spans: spans)

    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      let otelVersion = Headers.getUserAgentHeader()
      XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
      XCTAssertTrue(head.headers.contains { header in
          header.name.lowercased() == testHeader.0.lowercased() && header.value == testHeader.1
      })
      XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
    })
    XCTAssertNoThrow(try testServer.receiveBodyAndVerify { body in
      XCTAssertTrue(body.count > 0, "Body should not be empty")
      // Check that endpoint names are present in the protobuf data
      let bodyString = String(decoding: body, as: UTF8.self)
      XCTAssertTrue(bodyString.contains(endpointName1))
      XCTAssertTrue(bodyString.contains(endpointName2))
    })

    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  // This is not a thorough test of HTTPClient, but just enough to keep code coverage happy.
  // There is a more complete test as part of the DataDog exporter test
  func testHttpClient() {
    // Clear any previous requests
    testServer.clearReceivedRequests()
    
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)/some-route")!
    let httpClient = BaseHTTPClient()
    var request = URLRequest(url: endpoint)
    request.httpMethod = HTTPMethod.GET.rawValue

    httpClient.send(request: request) { result in
      switch result {
      case let .success(response):
        XCTAssertEqual(HTTPResponseStatus.ok.code, UInt(response.statusCode))
      case let .failure(error):
        XCTFail("Send failed: \(error)")
      }
    }

    // Assert the server received the expected request.
    XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
      XCTAssertEqual(head.version, .http1_1)
      XCTAssertEqual(head.method.rawValue, "GET")
      XCTAssertEqual(head.uri, "/some-route")
    })
    XCTAssertNoThrow(try testServer.receiveEnd())
  }

  func testFlush() {
    let endpoint = URL(string: "http://localhost:\(testServer.serverPort)/v1/traces")!
    let exporter = OtlpHttpTraceExporter(endpoint: endpoint)
    XCTAssertEqual(SpanExporterResultCode.success, exporter.flush())
  }

  private func generateFakeSpan(endpointName: String = "/api/endpoint") -> SpanData {
    let duration = 0.9
    let start = Date()
    let end = start.addingTimeInterval(duration)
    let testattributes: [String: AttributeValue] = ["foo": AttributeValue("bar")!, "fizz": AttributeValue("buzz")!]

    var testData = SpanData(traceId: TraceId.random(),
                            spanId: SpanId.random(),
                            name: "GET " + endpointName,
                            kind: SpanKind.server,
                            startTime: start,
                            endTime: end,
                            totalAttributeCount: 2)
    testData.settingAttributes(testattributes)
    testData.settingTotalAttributeCount(2)
    testData.settingHasEnded(true)
    testData.settingTotalRecordedEvents(0)
    testData.settingLinks([SpanData.Link]())
    testData.settingTotalRecordedLinks(0)
    testData.settingStatus(.ok)

    return testData
  }
}
