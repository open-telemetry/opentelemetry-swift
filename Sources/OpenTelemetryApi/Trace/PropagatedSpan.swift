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

/// The PropagatedSpan is the default Span that is used when no Span
/// implementation is available. All operations are no-op except context propagation.
class PropagatedSpan: Span {
    var name: String = ""

    var kind: SpanKind

    var context: SpanContext

    var scope: Scope?

    func end() {
        scope?.close()
    }

    func end(time: Date) {
        end()
    }

    /// Returns a DefaultSpan with an invalid SpanContext.
    convenience init() {
        self.init(context: SpanContext.invalid, kind: .client)
    }

    /// Creates an instance of this class with the SpanContext.
    /// - Parameter context: the SpanContext
    convenience init(context: SpanContext) {
        self.init(context: context, kind: .client)
    }

    /// Creates an instance of this class with the SpanContext and Span kind
    /// - Parameters:
    ///   - context: the SpanContext
    ///   - kind: the SpanKind
    init(context: SpanContext, kind: SpanKind) {
        self.context = context
        self.kind = kind
    }

    static func random() -> PropagatedSpan {
        return PropagatedSpan(context: SpanContext.create(traceId: TraceId.random(),
                                                       spanId: SpanId.random(),
                                                       traceFlags: TraceFlags(),
                                                       traceState: TraceState()),
                           kind: .client)
    }

    var isRecording: Bool {
        return false
    }

    var status: Status {
        get {
            return Status.ok
        }
        set {}
    }

    var description: String {
        return "PropagatedSpan"
    }

    func updateName(name: String) {}

    func setAttribute(key: String, value: AttributeValue?) {}

    func addEvent(name: String) {}

    func addEvent(name: String, timestamp: Date) {}

    func addEvent(name: String, attributes: [String: AttributeValue]) {}

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}
}
