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
import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetryProtocolExporterHttp
@testable import OpenTelemetrySdk
import XCTest

class OtlpHttpLogRecordExporterTests: XCTestCase {
    var testServer: NIOHTTP1TestServer!
    var group: MultiThreadedEventLoopGroup!
    var spanContext: SpanContext!
    
    override func setUp() {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        testServer = NIOHTTP1TestServer(group: group)
        
        let spanId = SpanId.random()
        let traceId = TraceId.random()
        spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try testServer.stop())
        XCTAssertNoThrow(try group.syncShutdownGracefully())
    }
    
    func testExport() {
        let testBody = AttributeValue.string("Helloworld" + String(Int.random(in: 1...100)))
        let logRecord = ReadableLogRecord(resource: Resource(),
                                          instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                          timestamp: Date(),
                                          observedTimestamp: Date.distantPast,
                                          spanContext: spanContext,
                                          severity: .fatal,
                                          body: testBody,
                                          attributes: ["event.name":AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
        
        let endpoint = URL(string: "http://localhost:\(testServer.serverPort)")!
        let exporter = OtlpHttpLogExporter(endpoint: endpoint)
        let _ = exporter.export(logRecords: [logRecord])
        
        // TODO: Use protobuf to verify that we have received the correct Log records      
        XCTAssertNoThrow(try testServer.receiveHeadAndVerify { head in
            let otelVersion = Headers.getUserAgentHeader()
            XCTAssertTrue(head.headers.contains(name: Constants.HTTP.userAgent))
            XCTAssertEqual(otelVersion, head.headers.first(name: Constants.HTTP.userAgent))
        })
        XCTAssertNoThrow(try testServer.receiveBodyAndVerify() { body in
            var contentsBuffer = ByteBuffer(buffer: body)
            let contents = contentsBuffer.readString(length: contentsBuffer.readableBytes)!
          XCTAssertTrue(contents.description.contains(testBody.description))
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
