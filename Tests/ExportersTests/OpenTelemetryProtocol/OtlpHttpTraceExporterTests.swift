//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOTestUtils
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporter
@testable import OpenTelemetrySdk
import XCTest

class OltpHttpTraceExporterTests: XCTestCase {
    var exporter: OtlpHttpTraceExporter!
    var testServer: NIOHTTP1TestServer!
    var group: MultiThreadedEventLoopGroup!
   
    override func setUp() {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        testServer = NIOHTTP1TestServer(group: group)
        exporter = OtlpHttpTraceExporter()
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try testServer.stop())
        XCTAssertNoThrow(try group.syncShutdownGracefully())
    }
    
    func testExport() {
        let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
        exporter = OtlpHttpTraceExporter(endpoint: endpoint)
        
        var spans: [SpanData] = []
        spans.append(generateFakeSpan())
        let result = exporter.export(spans: spans)
        XCTAssertEqual(result, SpanExporterResultCode.success)
        
        XCTAssertNoThrow(try testServer.receiveHead())
        XCTAssertNoThrow(try testServer.receiveBodyAndVerify() { body in
            // TODO what to do with the body?  How can we turn it back into spans?
            print("---------------------------------------------------------------------------")
            print("Body has \(body.readableBytes) readable bytes")
        })
        
        XCTAssertNoThrow(try testServer.receiveEnd())
    }
    
    private func generateFakeSpan() -> SpanData {
        let duration = 0.9
        let start = Date()
        let end = start.addingTimeInterval(duration)
                
        var testData = SpanData(traceId: TraceId.random(),
                                spanId: SpanId.random(),
                                name: "GET /api/endpoint",
                                kind: SpanKind.server,
                                startTime: start,
                                endTime: end)
        testData.settingHasEnded(true)
        testData.settingTotalRecordedEvents(0)
        testData.settingLinks([SpanData.Link]())
        testData.settingTotalRecordedLinks(0)
        testData.settingStatus(.ok)

        return testData
    }
}
