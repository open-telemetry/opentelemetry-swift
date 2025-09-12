//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(Compression)
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

  class OtlpHttpExporterBaseTests: XCTestCase {
    var exporter: OtlpHttpExporterBase!
    var spans: [SpanData] = []

    override func setUp() {
      super.setUp()

      spans = []
      let endpointName1 = "/api/foo" + String(Int.random(in: 1 ... 100))
      let endpointName2 = "/api/bar" + String(Int.random(in: 100 ... 500))
      spans.append(generateFakeSpan(endpointName: endpointName1))
      spans.append(generateFakeSpan(endpointName: endpointName2))
    }

    // Test for .gzip compression
    func testCreateRequestWithGzipCompression() {
      let config = OtlpConfiguration(compression: .gzip)

      exporter = OtlpHttpExporterBase(
        endpoint: URL(
          string: "http://example.com"
        )!,
        config: config,
        httpClient: BaseHTTPClient()
      )

      let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
      }

      let request = exporter.createRequest(body: body, endpoint: URL(string: "http://example.com")!)

      /// gzip
      let data = try! body.serializedData().gzip()

      // Verify Content-Encoding header is set to "gzip"
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Encoding"), "gzip")
      XCTAssertNotNil(request.httpBody)
      XCTAssertEqual(request.httpBody!.count, data!.count)
    }

    // Test for .deflate compression
    func testCreateRequestWithDeflateCompression() {
      let config = OtlpConfiguration(compression: .deflate)

      exporter = OtlpHttpExporterBase(
        endpoint: URL(
          string: "http://example.com"
        )!,
        config: config,
        httpClient: BaseHTTPClient()
      )

      let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
      }

      let request = exporter.createRequest(body: body, endpoint: URL(string: "http://example.com")!)

      /// deflate
      let data = try! body.serializedData().deflate()

      // Verify Content-Encoding header is set to "deflate"
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Encoding"), "deflate")
      XCTAssertNotNil(request.httpBody)
      XCTAssertEqual(request.httpBody!.count, data!.count)
    }

    // Test for .none compression (no compression)
    func testCreateRequestWithNoCompression() {
      let config = OtlpConfiguration(compression: .none)

      exporter = OtlpHttpExporterBase(
        endpoint: URL(
          string: "http://example.com"
        )!,
        config: config,
        httpClient: BaseHTTPClient()
      )

      let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
        $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
      }

      let request = exporter.createRequest(body: body, endpoint: URL(string: "http://example.com")!)

      let data = try! body.serializedData()

      // Verify Content-Encoding header is set to "deflate"
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Encoding"), nil)
      XCTAssertNotNil(request.httpBody)
      XCTAssertEqual(request.httpBody!.count, data.count)
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
#endif
