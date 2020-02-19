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

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class SpanDataTests: XCTestCase {
    let startEpochNanos: Int = 3000000000000 + 200
    let endEpochNanos: Int = 3001000000000 + 255

    func testdefaultValues() {
        let spanData = createBasicSpan()
        XCTAssertFalse(spanData.parentSpanId?.isValid ?? true)
        XCTAssertEqual(spanData.attributes, [String: AttributeValue]())
        XCTAssertEqual(spanData.timedEvents, [SpanData.TimedEvent]())
        XCTAssertEqual(spanData.links.count, 0)
        XCTAssertEqual(InstrumentationLibraryInfo(), spanData.instrumentationLibraryInfo)
        XCTAssertFalse(spanData.hasRemoteParent)
    }

    private func createBasicSpan() -> SpanData {
        return SpanData(traceId: TraceId(),
                        spanId: SpanId(),
                        traceFlags: TraceFlags(),
                        traceState: TraceState(),
                        resource: Resource(),
                        instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                        name: "spanName",
                        kind: .server,
                        startEpochNanos: startEpochNanos,
                        endEpochNanos: endEpochNanos,
                        hasRemoteParent: false)
    }
}
