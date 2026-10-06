//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk

final class LogRecordBuilderSdkTests: XCTestCase {
  private let mockProcessor = LogRecordProcessorMock()
  private let testClock = TestClock()
  private var sharedState: LoggerSharedState!

  override func setUp() {
    sharedState = LoggerSharedState(resource: .empty, logLimits: .init(), processors: [mockProcessor], clock: testClock)
  }

  func testGivenNeitherTimestampNorObservedSet_whenEmit_thenTimestampFromClockAndObservedFromClock() {
    // When
    LogRecordBuilderSdk(sharedState: sharedState, instrumentationScope: .init(), includeSpanContext: false)
      .emit()

    // Then
    XCTAssertEqual(mockProcessor.onEmitCalledTimes, 1)
    let logRecord = mockProcessor.onEmitCalledLogRecord
    XCTAssertEqual(logRecord?.timestamp, testClock.now)
    XCTAssertEqual(logRecord?.observedTimestamp, testClock.now)
  }

  func testGivenTimestampAndObservedSet_whenEmit_thenRecordHasTimestampAndObserved() {
    let timestamp = TestUtils.dateFromNanos(1234000001234)
    let observedTimestamp = TestUtils.dateFromNanos(1234000005678)

    // Given
    let logRecordBuilder = LogRecordBuilderSdk(sharedState: sharedState, instrumentationScope: .init(), includeSpanContext: false)
      .setTimestamp(timestamp)
      .setObservedTimestamp(observedTimestamp)

    // When
    logRecordBuilder.emit()

    // Then
    XCTAssertEqual(mockProcessor.onEmitCalledTimes, 1)
    let logRecord = mockProcessor.onEmitCalledLogRecord
    XCTAssertEqual(logRecord?.timestamp, timestamp)
    XCTAssertEqual(logRecord?.observedTimestamp, observedTimestamp)
  }

  func testSetEventName_Emits() {
    // Given
    let eventName = "session.start"
    LogRecordBuilderSdk(sharedState: sharedState, instrumentationScope: .init(), includeSpanContext: false)
      .setEventName(eventName)
      .emit()

    // Then
    XCTAssertEqual(mockProcessor.onEmitCalledTimes, 1)
    let logRecord = mockProcessor.onEmitCalledLogRecord
    XCTAssertEqual(logRecord?.eventName, eventName)
  }
}
