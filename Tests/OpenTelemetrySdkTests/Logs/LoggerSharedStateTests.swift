//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk

class LoggerSharedStateTests: XCTestCase {
  func testInit0Processors() {
    let process1 = LogRecordProcessorMock()
    let process2 = LogRecordProcessorMock()
    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [LogRecordProcessorMock](), clock: MillisClock())
    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 0)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is NoopLogRecordProcessor)

    sharedState.addLogRecordProcessor(process1)

    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 1)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is LogRecordProcessorMock)

    sharedState.addLogRecordProcessor(process2)
    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 2)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is MultiLogRecordProcessor)

    sharedState.activeLogRecordProcessor.onEmit(logRecord: ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "blah"), timestamp: Date(), attributes: [String: AttributeValue]()))

    XCTAssertTrue(process1.onEmitCalled)
    XCTAssertTrue(process2.onEmitCalled)

    sharedState.stop()
    XCTAssertTrue(sharedState.hasBeenShutdown)
    XCTAssertTrue(process1.shutdownCalled)
    XCTAssertTrue(process2.shutdownCalled)

    sharedState.stop()
    XCTAssertEqual(process1.shutdownCalledTimes, 1)
    XCTAssertEqual(process2.shutdownCalledTimes, 1)
  }

  func testInit1Processors() {
    let processor1 = LogRecordProcessorMock()
    let processor2 = LogRecordProcessorMock()

    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor1], clock: MillisClock())
    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 1)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is LogRecordProcessorMock)

    sharedState.addLogRecordProcessor(processor2)

    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 2)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is MultiLogRecordProcessor)
  }

  func testInitMultiProcessors() {
    let processor1 = LogRecordProcessorMock()
    let processor2 = LogRecordProcessorMock()

    let sharedState = LoggerSharedState(resource: Resource(), logLimits: LogLimits(), processors: [processor1, processor2], clock: MillisClock())
    XCTAssertEqual(sharedState.registeredLogRecordProcessors.count, 2)
    XCTAssertTrue(sharedState.activeLogRecordProcessor is MultiLogRecordProcessor)
  }
}
