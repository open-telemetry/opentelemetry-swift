//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
@testable import OpenTelemetryApi
import XCTest


class DefaultLoggerTests : XCTestCase {
    let defaultLogger = DefaultLogger.getInstance(false)
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]
    var spanContext: SpanContext!

    override func setUp() {
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())

    }
    
    func testDefaultLoggerNoops() {
        
        XCTAssertNoThrow(DefaultLogger.getInstance(false).logRecordBuilder().emit())
        
        XCTAssertNoThrow(defaultLogger.logRecordBuilder()
            .setSpanContext(spanContext)
            .setAttributes([:])
            .setTimestamp(Date())
            .setObservedTimestamp(Date())
            .setSeverity(.debug)
            .setBody(AttributeValue.string("hello, world"))
            .emit())
        
        XCTAssertNoThrow(defaultLogger.eventBuilder(name: "Event").emit())
        XCTAssertNoThrow(DefaultLogger.getInstance(true).eventBuilder(name: "Event").emit())

        
    }

    
}
