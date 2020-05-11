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
    var spanExporter1: SpanExporterMock!
    var spanExporter2: SpanExporterMock!
    var spanList: [SpanData]!

    override func setUp() {
        spanExporter1 = SpanExporterMock()
        spanExporter2 = SpanExporterMock()
        spanList = [TestUtils.makeBasicSpan()]
    }

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
        XCTAssertEqual(spanExporter1.exportCalledData, spanList)
        multiSpanExporter.shutdown()
        XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
    }

    func testTwoSpanExporter() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
        spanExporter1.returnValue = .success
        spanExporter2.returnValue = .success
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.success)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter1.exportCalledData, spanList)
        XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter2.exportCalledData, spanList)
        multiSpanExporter.shutdown()
        XCTAssertEqual(spanExporter1.shutdownCalledTimes, 1)
        XCTAssertEqual(spanExporter2.shutdownCalledTimes, 1)
    }

    func testTwoSpanExporter_OneReturnFailure() {
        let multiSpanExporter = MultiSpanExporter(spanExporters: [spanExporter1, spanExporter2])
        spanExporter1.returnValue = .success
        spanExporter2.returnValue = .failure
        XCTAssertEqual(multiSpanExporter.export(spans: spanList), SpanExporterResultCode.failure)
        XCTAssertEqual(spanExporter1.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter1.exportCalledData, spanList)
        XCTAssertEqual(spanExporter2.exportCalledTimes, 1)
        XCTAssertEqual(spanExporter2.exportCalledData, spanList)
    }
}
