/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import FaroExporter

final class FaroLogAdapterTests: XCTestCase {
    var mockDateProvider: MockDateProvider!
    
    // Test date: February 13, 2009 23:31:30 UTC
    let testDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: 2009,
            month: 2,
            day: 13,
            hour: 23,
            minute: 31,
            second: 30
        ))!
    }()
    let testISOString = "2009-02-13T23:31:30.000Z"
    
    override func setUp() {
        super.setUp()
        mockDateProvider = MockDateProvider(initialDate: testDate)
        FaroLogAdapter.dateProvider = mockDateProvider
    }
    
    override func tearDown() {
        FaroLogAdapter.dateProvider = DateProvider()
        super.tearDown()
    }
    
    func testBasicLogConversion() {
        // Given
        let logRecord = ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
            timestamp: testDate,
            body: AttributeValue.string("Test message"),
            attributes: [:]
        )
        
        // When
        let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: [logRecord])
        
        // Then
        XCTAssertEqual(faroLogs.count, 1)
        let faroLog = faroLogs[0]
        XCTAssertEqual(faroLog.timestamp, testISOString)
        XCTAssertEqual(faroLog.dateTimestamp, testDate)
        XCTAssertEqual(faroLog.message, "Test message")
        XCTAssertEqual(faroLog.level, FaroLogLevel.info)  // Default level
        XCTAssertNil(faroLog.context)
        XCTAssertNil(faroLog.trace)
    }
    
    func testSeverityMapping() {
        let testCases: [(Severity, FaroLogLevel)] = [
            (.trace, FaroLogLevel.trace),
            (.debug, FaroLogLevel.debug),
            (.info, FaroLogLevel.info),
            (.warn, FaroLogLevel.warning),
            (.error, FaroLogLevel.error),
            (.fatal, FaroLogLevel.error)  // Fatal maps to error in Faro
        ]
        
        for (severity, expectedLevel) in testCases {
            let logRecord = ReadableLogRecord(
                resource: Resource(),
                instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
                timestamp: testDate,
                severity: severity,
                body: AttributeValue.string("Test message"),
                attributes: [:]
            )
            
            let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: [logRecord])
            XCTAssertEqual(faroLogs[0].level, expectedLevel, "Failed for severity \(severity)")
        }
    }
    
    func testAttributesConversion() {
        // Given
        let attributes: [String: AttributeValue] = [
            "string": .string("value"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true)
        ]
        
        let logRecord = ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
            timestamp: testDate,
            body: AttributeValue.string("Test message"),
            attributes: attributes
        )
        
        // When
        let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: [logRecord])
        
        // Then
        XCTAssertEqual(faroLogs.count, 1)
        let faroLog = faroLogs[0]
        XCTAssertNotNil(faroLog.context)
        XCTAssertEqual(faroLog.context?["string"], "value")
        XCTAssertEqual(faroLog.context?["int"], "42")
        XCTAssertEqual(faroLog.context?["double"], "3.14")
        XCTAssertEqual(faroLog.context?["bool"], "true")
    }
    
    func testTraceContextConversion() {
        // Given
        let traceId = TraceId(fromBytes: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
        let spanId = SpanId(fromBytes: [1, 2, 3, 4, 5, 6, 7, 8])
        let spanContext = SpanContext.create(
            traceId: traceId,
            spanId: spanId,
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
        
        let logRecord = ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
            timestamp: testDate,
            spanContext: spanContext,
            body: AttributeValue.string("Test message"),
            attributes: [:]
        )
        
        // When
        let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: [logRecord])
        
        // Then
        XCTAssertEqual(faroLogs.count, 1)
        let faroLog = faroLogs[0]
        XCTAssertNotNil(faroLog.trace)
        XCTAssertEqual(faroLog.trace?.traceId, traceId.hexString)
        XCTAssertEqual(faroLog.trace?.spanId, spanId.hexString)
    }
    
    func testMultipleLogConversion() {
        // Given
        let logRecords = [
            ReadableLogRecord(
                resource: Resource(),
                instrumentationScopeInfo: InstrumentationScopeInfo(name: "test1"),
                timestamp: testDate,
                severity: .info,
                body: AttributeValue.string("Message 1"),
                attributes: [:]
            ),
            ReadableLogRecord(
                resource: Resource(),
                instrumentationScopeInfo: InstrumentationScopeInfo(name: "test2"),
                timestamp: testDate,
                severity: .error,
                body: AttributeValue.string("Message 2"),
                attributes: [:]
            )
        ]
        
        // When
        let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: logRecords)
        
        // Then
        XCTAssertEqual(faroLogs.count, 2)
        XCTAssertEqual(faroLogs[0].message, "Message 1")
        XCTAssertEqual(faroLogs[0].level, FaroLogLevel.info)
        XCTAssertEqual(faroLogs[1].message, "Message 2")
        XCTAssertEqual(faroLogs[1].level, FaroLogLevel.error)
    }
    
    func testEmptyBody() {
        // Given
        let logRecord = ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test"),
            timestamp: testDate,
            body: nil,
            attributes: [:]
        )
        
        // When
        let faroLogs = FaroLogAdapter.toFaroLogs(logRecords: [logRecord])
        
        // Then
        XCTAssertEqual(faroLogs.count, 1)
        XCTAssertEqual(faroLogs[0].message, "")
    }
} 