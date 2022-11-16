/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// The PropagatedSpan is the default Span that is used when no Span
/// implementation is available. All operations are no-op except context propagation.
class PropagatedSpan: Span {
    var name: String

    var kind: SpanKind

    var context: SpanContext

    func end() {
        OpenTelemetry.instance.contextProvider.removeContextForSpan(self)
    }

    func end(time: Date) {
        end()
    }

    /// Returns a DefaultSpan with an invalid SpanContext.
    convenience init() {
        let invalidContext = SpanContext.create(traceId: TraceId(),
                                                spanId: SpanId(),
                                                traceFlags: TraceFlags(),
                                                traceState: TraceState())
        self.init(name: "", context: invalidContext, kind: .client)
    }

    /// Creates an instance of this class with the SpanContext.
    /// - Parameter context: the SpanContext
    convenience init(context: SpanContext) {
        self.init(name: "", context: context, kind: .client)
    }

    /// Creates an instance of this class with the SpanContext and Span kind
    /// - Parameters:
    ///   - context: the SpanContext
    ///   - kind: the SpanKind
    convenience init(context: SpanContext, kind: SpanKind) {
        self.init(name: "", context: context, kind: kind)
    }

    /// Creates an instance of this class with the SpanContext and Span name
    /// - Parameters:
    ///   - context: the SpanContext
    ///   - kind: the SpanKind
    convenience init(name: String, context: SpanContext) {
        self.init(name: name, context: context, kind: .client)
    }

    /// Creates an instance of this class with the SpanContext, Span kind and name
    /// - Parameters:
    ///   - context: the SpanContext
    ///   - kind: the SpanKind
    init(name: String, context: SpanContext, kind: SpanKind) {
        self.name = name
        self.context = context
        self.kind = kind
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
