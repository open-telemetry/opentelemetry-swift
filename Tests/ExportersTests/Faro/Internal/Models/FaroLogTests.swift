/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
@testable import FaroExporter

final class FaroLogTests: XCTestCase {
  // MARK: - Test Data

  private let timestamp = "2024-03-20T10:00:00Z"
  private let message = "Test message"
  private let context = ["key": "value"]
  private let trace = FaroTraceContext.create(traceId: "trace123", spanId: "span456")

  // MARK: - Equatable Tests

  func testEquatableEqual() {
    // Given
    let log1 = FaroLog(
      timestamp: timestamp,
      level: .info,
      message: message,
      context: context,
      trace: trace
    )

    let log2 = FaroLog(
      timestamp: timestamp,
      level: .info,
      message: message,
      context: context,
      trace: trace
    )

    // Then
    XCTAssertEqual(log1, log2)
  }

  func testEquatableNotEqualDifferentTimestamp() {
    // Given
    let log1 = FaroLog(timestamp: "2024-03-20T10:00:00Z", level: .info, message: message, context: context, trace: trace)
    let log2 = FaroLog(timestamp: "2024-03-20T10:00:01Z", level: .info, message: message, context: context, trace: trace)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with different timestamp")
  }

  func testEquatableNotEqualDifferentLevel() {
    // Given
    let log1 = FaroLog(timestamp: timestamp, level: .info, message: message, context: context, trace: trace)
    let log2 = FaroLog(timestamp: timestamp, level: .error, message: message, context: context, trace: trace)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with different level")
  }

  func testEquatableNotEqualDifferentMessage() {
    // Given
    let log1 = FaroLog(timestamp: timestamp, level: .info, message: "Message 1", context: context, trace: trace)
    let log2 = FaroLog(timestamp: timestamp, level: .info, message: "Message 2", context: context, trace: trace)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with different message")
  }

  func testEquatableNotEqualDifferentContext() {
    // Given
    let log1 = FaroLog(timestamp: timestamp, level: .info, message: message, context: ["key1": "value1"], trace: trace)
    let log2 = FaroLog(timestamp: timestamp, level: .info, message: message, context: ["key2": "value2"], trace: trace)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with different context")
  }

  func testEquatableNotEqualDifferentTrace() {
    // Given
    let trace1 = FaroTraceContext.create(traceId: "trace1", spanId: "span1")
    let trace2 = FaroTraceContext.create(traceId: "trace2", spanId: "span2")

    let log1 = FaroLog(timestamp: timestamp, level: .info, message: message, context: context, trace: trace1)
    let log2 = FaroLog(timestamp: timestamp, level: .info, message: message, context: context, trace: trace2)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with different trace")
  }

  func testEquatableWithNilValues() {
    // Given
    let log1 = FaroLog(
      timestamp: timestamp,
      level: .info,
      message: message,
      context: nil,
      trace: nil
    )

    let log2 = FaroLog(
      timestamp: timestamp,
      level: .info,
      message: message,
      context: nil,
      trace: nil
    )

    // Then
    XCTAssertEqual(log1, log2, "Should be equal with nil optional values")
  }

  func testEquatableWithMixedNilValues() {
    // Given
    let log1 = FaroLog(timestamp: timestamp, level: .info, message: message, context: context, trace: nil)
    let log2 = FaroLog(timestamp: timestamp, level: .info, message: message, context: nil, trace: trace)

    // Then
    XCTAssertNotEqual(log1, log2, "Should not be equal with mixed nil values")
  }
}
