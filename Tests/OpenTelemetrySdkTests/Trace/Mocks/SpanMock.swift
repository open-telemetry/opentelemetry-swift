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
import OpenTelemetrySdk

class SpanMock: Span {
    var name: String = ""

    var kind: SpanKind {
        return .client
    }

    var context: SpanContext = SpanContext.create(traceId: TraceId.random(), spanId: SpanId.random(), traceFlags: TraceFlags(), traceState: TraceState())

    var isRecording: Bool = false

    var status: Status = .unset

    var scope: Scope?

    func updateName(name: String) {}

    func setAttribute(key: String, value: AttributeValue?) {}

    func addEvent(name: String) {}

    func addEvent(name: String, attributes: [String: AttributeValue]) {}

    func addEvent(name: String, timestamp: Date) {}

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}

    var description: String = "SpanMock"
}
