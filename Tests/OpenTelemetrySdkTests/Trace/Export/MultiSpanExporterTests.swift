// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

@testable import OpenTelemetrySdk
import XCTest

class MultiSpanExporterTests: XCTestCase {
    let spanExporter1 = SpanExporterMock()
    let spanExporter2 = SpanExporterMock()
    let spanList = [TestUtils.makeBasicSpan()]

    func testEmpty() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [SpanExporter]())

        _ = multiSpanExporter.export(spans: spanList)
        multiSpanExporter.shutdown()
    }

    func testOneSpanExporter() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1])
        spanExporter1.returnValue = .success
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.success)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        multiSpanExporter.shutdown()
        XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
    }

    func testTwoSpanExporter() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
        spanExporter1.returnValue = .success
        spanExporter2.returnValue = .success
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.success)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
        multiSpanExporter.shutdown()
        XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
        XCTAssertEqual(spanExporter2.shutdownCalledTimes, 1)
    }

    func testTwoSpanExporter_OneReturnNoneRetryable() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
        spanExporter1.returnValue = .success
        spanExporter1.returnValue = .failedNotRetryable
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.failedNotRetryable)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
    }

    func testTwoSpanExporter_OneReturnRetryable() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
        spanExporter1.returnValue = .success
        spanExporter1.returnValue = .failedRetryable
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.failedRetryable)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
    }
}
