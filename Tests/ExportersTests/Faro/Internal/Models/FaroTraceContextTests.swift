/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import XCTest
@testable import FaroExporter

final class FaroTraceContextTests: XCTestCase {
    
    func testEquatableEqual() {
        // Given
        let context1 = FaroTraceContext.create(traceId: "trace123", spanId: "span456")
        let context2 = FaroTraceContext.create(traceId: "trace123", spanId: "span456")
        
        // Then
        XCTAssertEqual(context1, context2)
    }
    
    func testEquatableNotEqual() {
        // Given
        let context1 = FaroTraceContext.create(traceId: "trace123", spanId: "span456")
        let context2 = FaroTraceContext.create(traceId: "trace789", spanId: "span456")
        let context3 = FaroTraceContext.create(traceId: "trace123", spanId: "span789")
        
        // Then
        XCTAssertNotEqual(context1, context2, "Should not be equal with different traceId")
        XCTAssertNotEqual(context1, context3, "Should not be equal with different spanId")
    }
    
    func testEquatableWithNil() {
        // Given
        let context1 = FaroTraceContext.create(traceId: nil, spanId: nil)
        let context2 = FaroTraceContext.create(traceId: nil, spanId: nil)
        
        // Then
        XCTAssertNil(context1)
        XCTAssertNil(context2)
    }
    
    func testCreateWithValidValuesReturnsContext() {
        // Given
        let traceId = "trace123"
        let spanId = "span456"
        
        // When
        let context = FaroTraceContext.create(traceId: traceId, spanId: spanId)
        
        // Then
        XCTAssertNotNil(context)
        XCTAssertEqual(context?.traceId, traceId)
        XCTAssertEqual(context?.spanId, spanId)
    }
    
    func testCreateWithNilValuesReturnsNil() {
        // Given/When
        let context1 = FaroTraceContext.create(traceId: nil, spanId: "span456")
        let context2 = FaroTraceContext.create(traceId: "trace123", spanId: nil)
        let context3 = FaroTraceContext.create(traceId: nil, spanId: nil)
        let context4 = FaroTraceContext.create(traceId: "", spanId: "")
        
        // Then
        XCTAssertNotNil(context1, "Should not be nil when spanId has value")
        XCTAssertNotNil(context2, "Should not be nil when traceId has value")
        XCTAssertNil(context3, "Should be nil when both values are nil")
        XCTAssertNil(context4, "Should be nil when both values are empty strings")
    }
    
    func testCreateWithEmptyStrings() {
        // Given/When
        let context1 = FaroTraceContext.create(traceId: "", spanId: "span456")
        let context2 = FaroTraceContext.create(traceId: "trace123", spanId: "")
        
        // Then
        XCTAssertNotNil(context1, "Should not be nil when spanId has value")
        XCTAssertNotNil(context2, "Should not be nil when traceId has value")
        XCTAssertEqual(context1?.spanId, "span456")
        XCTAssertEqual(context2?.traceId, "trace123")
    }
} 