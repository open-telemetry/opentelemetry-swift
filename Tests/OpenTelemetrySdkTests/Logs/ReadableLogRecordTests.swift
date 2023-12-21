//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class ReadableLogRecordTests : XCTestCase {
    let processor = LogRecordProcessorMock()
    

    func testLogRecord() {
        let observedTimestamp = Date()
        let provider = LoggerProviderBuilder().with(logLimits: LogLimits(maxAttributeCount: 1, maxAttributeLength: 1)).with(processors: [processor]).build()
        let logger = provider.get(instrumentationScopeName: "temp")
        logger.logRecordBuilder()
            .setBody(AttributeValue.string("hello, world"))
            .setSeverity(.debug)
            .setObservedTimestamp(observedTimestamp)
            .setAttributes(["firstAttribute": AttributeValue.string("only the 'o' will be captured"), "secondAttribute": AttributeValue.string("this attribute will be dropped")])
            .emit()
        
            let logRecord = processor.onEmitCalledLogRecord
        XCTAssertEqual(logRecord?.observedTimestamp, observedTimestamp)
        XCTAssertEqual(logRecord?.body, AttributeValue.string("hello, world"))
        XCTAssertEqual(logRecord?.attributes.count, 1)
        let key = logRecord?.attributes.keys.first
        XCTAssertEqual(logRecord?.attributes[key!]?.description.count, 1)
        
    }
}
