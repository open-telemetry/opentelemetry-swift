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

class MultiSpanProcessorTest: XCTestCase {
    let spanProcessor1 = SpanProcessorMock()
    let spanProcessor2 = SpanProcessorMock()
    let readableSpan = ReadableSpanMock()

    func testEmpty() {
        let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [SpanProcessor]())
        multiSpanProcessor.onStart(span: readableSpan)
        multiSpanProcessor.onEnd(span: readableSpan)
        multiSpanProcessor.shutdown()
    }

    func testOneSpanProcessor() {
        let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1])
        multiSpanProcessor.onStart(span: readableSpan)
        XCTAssert(spanProcessor1.onStartCalledSpan === readableSpan)
        multiSpanProcessor.onEnd(span: readableSpan)
        XCTAssert(spanProcessor1.onEndCalledSpan === readableSpan)
        multiSpanProcessor.shutdown()
        XCTAssertTrue(spanProcessor1.shutdownCalled)
    }

    func testTwoSpanProcessor() {
        let multiSpanProcessor = MultiSpanProcessor(spanProcessors: [spanProcessor1, spanProcessor2])

        multiSpanProcessor.onStart(span: readableSpan)
        XCTAssert(spanProcessor1.onStartCalledSpan === readableSpan)
        XCTAssert(spanProcessor2.onStartCalledSpan === readableSpan)

        multiSpanProcessor.onEnd(span: readableSpan)
        XCTAssert(spanProcessor1.onEndCalledSpan === readableSpan)
        XCTAssert(spanProcessor2.onEndCalledSpan === readableSpan)

        multiSpanProcessor.shutdown()
        XCTAssertTrue(spanProcessor1.shutdownCalled)
        XCTAssertTrue(spanProcessor2.shutdownCalled)
    }
}
