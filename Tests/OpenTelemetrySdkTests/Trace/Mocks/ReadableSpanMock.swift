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

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetrySdk

class ReadableSpanMock: ReadableSpan {
    var hasEnded: Bool = false
    var latencyNanos: UInt64 = 0

    var kind: SpanKind {
        return .client
    }

    var instrumentationLibraryInfo: InstrumentationLibraryInfo = InstrumentationLibraryInfo()

    var name: String = "ReadableSpanMock"

    var forcedReturnSpanContext: SpanContext?
    var forcedReturnSpanData: SpanData?

    func toSpanData() -> SpanData {
        return forcedReturnSpanData ?? SpanData(traceId: context.traceId,
                                                spanId: context.spanId,
                                                traceFlags: context.traceFlags,
                                                traceState: TraceState(),
                                                resource: Resource(attributes: [String: AttributeValue]()),
                                                instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                                                name: "ReadableSpanMock",
                                                kind: .client,
                                                startEpochNanos: 0,
                                                endEpochNanos: 0,
                                                hasRemoteParent: false)
    }

    var context: SpanContext {
        forcedReturnSpanContext ?? SpanContext.create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())
    }

    var isRecordingEvents: Bool = false

    var status: Status?

    func updateName(name: String) {
    }

    func setAttribute(key: String, value: AttributeValue?) {
    }

    func addEvent(name: String) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue]) {
    }

    func addEvent<E>(event: E) where E: Event {
    }

    func addEvent(name: String, timestamp: Date) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
    }

    func addEvent<E>(event: E, timestamp: Date) where E: Event {
    }
    
    var description: String = "ReadableSpanMock"
}
