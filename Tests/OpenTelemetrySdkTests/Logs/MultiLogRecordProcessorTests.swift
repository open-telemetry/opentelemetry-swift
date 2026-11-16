//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MultiLogRecordProcessorTest: XCTestCase {
  var processor1 = LogRecordProcessorMock()
  var processor2 = LogRecordProcessorMock()
  var readableLogRecord = ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "Test"), timestamp: Date(), attributes: [String: AttributeValue]())

  func testEmpty() {
    let multiLog = MultiLogRecordProcessor(logRecordProcessors: [LogRecordProcessor]())
    multiLog.onEmit(logRecord: readableLogRecord)
    _ = multiLog.shutdown(explicitTimeout: nil)
  }

  func testMultiProcessor() {
    let multiLog = MultiLogRecordProcessor(logRecordProcessors: [processor1, processor2])
    multiLog.onEmit(logRecord: readableLogRecord)

    XCTAssertTrue(processor1.onEmitCalled)
    XCTAssertTrue(processor2.onEmitCalled)

    _ = multiLog.forceFlush(explicitTimeout: nil)

    XCTAssertTrue(processor1.forceFlushCalled)
    XCTAssertTrue(processor2.forceFlushCalled)

    _ = multiLog.shutdown(explicitTimeout: nil)

    XCTAssertTrue(processor1.shutdownCalled)
    XCTAssertTrue(processor2.shutdownCalled)
  }
}
