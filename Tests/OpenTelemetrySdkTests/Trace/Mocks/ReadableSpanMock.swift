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
    var latencyNanos: Int = 0

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
                                                resource: Resource(labels: [String: String]()),
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

    func setAttribute(key: String, value: String) {
    }

    func setAttribute(key: String, value: Int) {
    }

    func setAttribute(key: String, value: Double) {
    }

    func setAttribute(key: String, value: Bool) {
    }

    func setAttribute(key: String, value: AttributeValue) {
    }

    func addEvent(name: String) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue]) {
    }

    func addEvent<E>(event: E) where E: Event {
    }

    func addEvent(name: String, timestamp: Int) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Int) {
    }

    func addEvent<E>(event: E, timestamp: Int) where E: Event {
    }

    func end() {
    }

    func end(endOptions: EndSpanOptions) {
    }

    var description: String = "ReadableSpanMock"
}
