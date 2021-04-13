// Copyright 2021, OpenTelemetry Authors
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

import Foundation
@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import URLSessionInstrumentation
import XCTest

final class URLSessionConfigurationTests: XCTestCase {
    override public func setUp() {}

    public func testOverrideSpanName() {
        let request = URLRequest(url: URL(string: "http://google.com")!)
        class Check {
            public var shouldRecordPayloadCalled: Bool = false
            public var shouldInstrumentCalled: Bool = false
            public var nameSpanCalled: Bool = false
            public var shouldInjectTracingHeadersCalled: Bool = false
            public var createdRequestCalled: Bool = false
        }

        let checker = Check()

        let instrumentation = URLSessionInstrumentation(configuration: URLSessionConfiguration(shouldRecordPayload:nil,
            shouldInstrument: nil,
            nameSpan: { [weak checker] _ in
                checker?.nameSpanCalled = true
                return "new name"
            },
            shouldInjectTracingHeaders: nil,
            createdRequest: nil,
            receivedResponse: nil,
            receivedError: nil))

        URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: instrumentation, shouldInjectHeaders: true)

        XCTAssertEqual(true, checker.nameSpanCalled)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
        let span = URLSessionLogger.runningSpans["id"]!
        XCTAssertEqual("new name", span.name)
    }

    public func testDefaultSpanName() {
        let request = URLRequest(url: URL(string: "http://google.com")!)

        let instrumentation = URLSessionInstrumentation(configuration: URLSessionConfiguration(shouldRecordPayload:nil,
            shouldInstrument: nil,
            nameSpan: nil,
            shouldInjectTracingHeaders: nil,
            createdRequest: nil,
            receivedResponse: nil,
            receivedError: nil))

        URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: instrumentation, shouldInjectHeaders: true)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
        let span = URLSessionLogger.runningSpans["id"]!
        XCTAssertEqual("HTTP GET", span.name)
    }

    public func testDefaultSpanWithNameClosure() {
        let request = URLRequest(url: URL(string: "http://google.com")!)
        class Check {
            public var shouldRecordPayloadCalled: Bool = false
            public var shouldInstrumentCalled: Bool = false
            public var nameSpanCalled: Bool = false
            public var shouldInjectTracingHeadersCalled: Bool = false
            public var createdRequestCalled: Bool = false
        }

        let checker = Check()

        let instrumentation = URLSessionInstrumentation(configuration: URLSessionConfiguration(shouldRecordPayload:nil,
            shouldInstrument: nil,
            nameSpan: { [weak checker] _ in
                checker?.nameSpanCalled = true
                return nil
            },
            shouldInjectTracingHeaders: nil,
            createdRequest: nil,
            receivedResponse: nil,
            receivedError: nil))

        URLSessionLogger.processAndLogRequest(request, sessionTaskId: "id", instrumentation: instrumentation, shouldInjectHeaders: true)

        XCTAssertEqual(true, checker.nameSpanCalled)

        XCTAssertEqual(1, URLSessionLogger.runningSpans.count)
        let span = URLSessionLogger.runningSpans["id"]!
        XCTAssertEqual("HTTP GET", span.name)
    }
}
