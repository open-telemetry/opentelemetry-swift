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
        let testBody = "Hello world " + String(Int.random(in: 1...100))
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
        XCTAssertNoThrow(try testServer.receiveHead())
        XCTAssertNoThrow(try testServer.receiveBodyAndVerify() { body in
            var contentsBuffer = ByteBuffer(buffer: body)
            let contents = contentsBuffer.readString(length: contentsBuffer.readableBytes)!
            XCTAssertTrue(contents.contains(testBody))
        })
        
        XCTAssertNoThrow(try testServer.receiveEnd())
        
        exporter.shutdown()
    }
}
