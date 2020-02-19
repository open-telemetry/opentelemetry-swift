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

@testable import OpenTelemetryApi
import XCTest

class BinaryFormatTests: XCTestCase {
    let traceId_bytes: [UInt8] = [64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79]
    var traceId: TraceId!
    let spanId_bytes: [UInt8] = [97, 98, 99, 100, 101, 102, 103, 104]
    var spanId: SpanId!
    let traceOptions_byte: UInt8 = 1
    var traceOptions: TraceFlags!
    let example_bytes: [UInt8] = [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 1, 97, 98, 99, 100,
                                  101, 102, 103, 104, 2, 1]
    var invalidSpanContext: SpanContext!
    let binaryFormat = BinaryTraceContextFormat()

    override func setUp() {
        traceId = TraceId(fromBytes: traceId_bytes)
        spanId = SpanId(fromBytes: spanId_bytes)
        traceOptions = TraceFlags(fromByte: traceOptions_byte)
        invalidSpanContext = DefaultSpan().context
    }

    private func testSpanContextConversion(spanContext: SpanContext) {
        let propagatedBinarySpanContext = binaryFormat.fromByteArray(bytes: binaryFormat.toByteArray(spanContext: spanContext))
        XCTAssertEqual(propagatedBinarySpanContext, spanContext)
    }

    func testPropagate_SpanContextTracingEnabled() {
        testSpanContextConversion(spanContext: SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags().settingIsSampled(true), traceState: TraceState()))
    }

    func testPropagate_SpanContextNoTracing() {
        testSpanContextConversion(
            spanContext: SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState()))
    }

    func testToBinaryValue_InvalidSpanContext() {
        XCTAssertEqual(binaryFormat.toByteArray(spanContext: invalidSpanContext), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0])
    }

    func testFromBinaryValue_BinaryExampleValue() {
        XCTAssertEqual(binaryFormat.fromByteArray(bytes: example_bytes), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceOptions, traceState: TraceState()))
    }

    func testFromBinaryValue_EmptyInput() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [UInt8]()))
    }

    func testFromBinaryValue_UnsupportedVersionId() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [66, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 97, 98, 99, 100, 101,
                                                        102, 103, 104, 1]))
    }

    func testFromBinaryValue_UnsupportedFieldIdFirst() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [0, 4, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 1, 97, 98, 99, 100, 101, 102, 103, 104, 2, 1]))
    }

    func testFromBinaryValue_UnsupportedFieldIdSecond() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 3, 97, 98, 99, 100,
                                                        101, 102, 103, 104, 2, 1]))
    }

    func testFromBinaryValue_UnsupportedFieldIdThird_skipped() {
        XCTAssertTrue(binaryFormat.fromByteArray(bytes: [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 1, 97,
                                                         98, 99, 100, 101, 102, 103, 104, 0, 1])!.isValid)
    }

    func testFromBinaryValue_ShorterTraceId() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76]))
    }

    func testFromBinaryValue_ShorterSpanId() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [0, 1, 97, 98, 99, 100, 101, 102, 103]))
    }

    func testFromBinaryValue_ShorterTraceFlags() {
        XCTAssertNil(binaryFormat.fromByteArray(bytes: [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 1, 97, 98, 99, 100,
                                                        101, 102, 103, 104, 2]))
    }

    func testFromBinaryValue_MissingTraceFlagsOk() {
        let extracted = binaryFormat.fromByteArray(bytes: [0, 0, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 1, 97, 98, 99,
                                                           100, 101, 102, 103, 104])
        XCTAssertTrue(extracted!.isValid)
        XCTAssertEqual(extracted?.traceFlags, TraceFlags())
    }
}
