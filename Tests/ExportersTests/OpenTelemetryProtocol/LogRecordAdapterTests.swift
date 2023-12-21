//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


import Foundation
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk
import XCTest

class LogRecordAdapterTests : XCTestCase {
    let traceIdBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4]
    let spanIdBytes: [UInt8] = [0, 0, 0, 0, 4, 3, 2, 1]
    var traceId: TraceId!
    var spanId: SpanId!
    let tracestate = TraceState()
    var spanContext: SpanContext!
    

    override func setUp() {
        traceId = TraceId(fromBytes: traceIdBytes)
        spanId = SpanId(fromBytes: spanIdBytes)
        spanContext = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: tracestate)
    }
    
    func testToResourceProto() {
        let logRecord = ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"), timestamp: Date(), attributes: ["event.name":AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
        
        let result = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: [logRecord])
        
        XCTAssertTrue(result[0].scopeLogs.count > 0)
    }
    
    func testToProto() {
        let timestamp = Date()
        let logRecord = ReadableLogRecord(resource: Resource(),
                                          instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
                                          timestamp: timestamp,
                                          observedTimestamp: Date.distantPast,
                                          spanContext: spanContext,
                                          severity: .fatal,
                                          body: AttributeValue.string("Hello, world"),
                                          attributes: ["event.name":AttributeValue.string("name"), "event.domain": AttributeValue.string("domain")])
        
        let protoLog = LogRecordAdapter.toProtoLogRecord(logRecord: logRecord)
        
       XCTAssertEqual(protoLog.body.stringValue, "Hello, world")
        XCTAssertEqual(protoLog.hasBody, true)
        XCTAssertEqual(protoLog.severityText, "FATAL")
        XCTAssertEqual(protoLog.observedTimeUnixNano, Date.distantPast.timeIntervalSince1970.toNanoseconds)
        XCTAssertEqual(protoLog.severityNumber.rawValue, Severity.fatal.rawValue)
        XCTAssertEqual(protoLog.spanID, Data(bytes: spanIdBytes, count: 8))
        XCTAssertEqual(protoLog.traceID, Data(bytes: traceIdBytes, count: 16))
        XCTAssertEqual(protoLog.timeUnixNano, timestamp.timeIntervalSince1970.toNanoseconds)
        XCTAssertEqual(protoLog.attributes.count, 2)
    }
}
