/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol SpanBuilder: AnyObject {
    /// Sets the parent Span to use. If not set, the value of OpenTelemetryContext.activeSpan
    /// at startSpan() time will be used as parent.
    ///
    /// This must be used to create a Span when manual Context propagation is used
    /// OR when creating a root Span with a parent with an invalid SpanContext.
    ///
    /// Observe this is the preferred method when the parent is a Span created within the
    /// process. Using its SpanContext as parent remains as a valid, albeit inefficient,
    /// operation.
    ///
    /// If called multiple times, only the last specified value will be used. Observe that the
    /// state defined by a previous call to setNoParent() will be discarded.
    ///
    /// - Parameter parent: the Span used as parent.
    @discardableResult func setParent(_ parent: Span) -> Self

    /// Sets the parent SpanContext to use. If not set, the value of
    /// OpenTelemetryContext.activeSpan at startSpan() time will be used as parent.
    ///
    /// Similar to setParent(Span parent) but this must be used to create a
    /// Span when the parent is in a different process. This is only intended for use by RPC systems
    /// or similar.
    ///
    /// If no SpanContext is available, users must call setNoParent in order to
    /// create a root Span for a new trace.
    ///
    /// If called multiple times, only the last specified value will be used. Observe that the
    /// state defined by a previous call to setNoParent() will be discarded.
    ///
    /// - Parameter parent: the SpanContext used as parent.
    @discardableResult func setParent(_ parent: SpanContext) -> Self

    /// Sets the option to become a root Span for a new trace. If not set, the value of
    /// OpenTelemetryContext.activeSpan at startSpan() time will be used as parent.
    ///
    /// Observe that any previously set parent will be discarded.
    @discardableResult func setNoParent() -> Self

    /// Adds a Link to the newly created Span.
    ///
    /// - Parameter spanContext: the context of the linked Span
    @discardableResult func addLink(spanContext: SpanContext) -> Self

    /// Adds a Link to the newly created Span.
    /// - Parameters:
    ///   - spanContext: the context of the linked Span
    ///   - attributes: the attributes of the Link
    @discardableResult func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self

    /// Sets an attribute to the newly created Span. If SpanBuilder previously
    /// contained a mapping for the key, the old value is replaced by the specified value.
    /// - Parameters:
    ///   - key: the key for this attribute
    ///   - value: the value for this attribute
    @discardableResult func setAttribute(key: String, value: String) -> Self

    /// Sets an attribute to the newly created Span. If SpanBuilder previously
    /// contained a mapping for the key, the old value is replaced by the specified value.
    /// - Parameters:
    ///   - key: the key for this attribute
    ///   - value: the value for this attribute
    @discardableResult func setAttribute(key: String, value: Int) -> Self

    /// Sets an attribute to the newly created Span. If SpanBuilder previously
    /// contained a mapping for the key, the old value is replaced by the specified value.
    /// - Parameters:
    ///   - key: the key for this attribute
    ///   - value: the value for this attribute
    @discardableResult func setAttribute(key: String, value: Double) -> Self

    /// Sets an attribute to the newly created Span. If SpanBuilder previously
    /// contained a mapping for the key, the old value is replaced by the specified value.
    /// - Parameters:
    ///   - key: the key for this attribute
    ///   - value: the value for this attribute
    @discardableResult func setAttribute(key: String, value: Bool) -> Self

    /// Sets an attribute to the newly created Span. If SpanBuilder previously
    /// contained a mapping for the key, the old value is replaced by the specified value.
    /// - Parameters:
    ///   - key: the key for this attribute
    ///   - value: the value for this attribute, pass nil to remove previous value
    @discardableResult func setAttribute(key: String, value: AttributeValue) -> Self

    /// Sets the Span.Kind for the newly created Span. If not called, the
    /// implementation will provide a default value Span.Kind#INTERNAL.
    /// - Parameter spanKind: the kind of the newly created Span
    @discardableResult func setSpanKind(spanKind: SpanKind) -> Self

    /// Sets an explicit start timestamp for the newly created Span.
    ///
    /// Use this method to specify an explicit start timestamp. If not called, the implementation
    /// will use the timestamp value at #startSpan() time, which should be the default case.
    /// - Parameter startTimestamp: the explicit start timestamp of the newly created Span in nanos since epoch.
    @discardableResult func setStartTime(time: Date) -> Self

    /// Sets the Span as the active Span in the current context when started.
    /// - Parameter active: If the span will be set as the activeSpan
    @discardableResult func setActive(_ active: Bool) -> Self

    /// Starts a new Span.
    ///
    /// Users must manually call Span.end() to end this Span
    ///
    /// Does not install the newly created Span to the current Context.
    func startSpan() -> Span
}

public extension SpanBuilder {
    @discardableResult func setAttribute(key: String, value: String) -> Self {
        return setAttribute(key: key, value: AttributeValue.string(value))
    }

    @discardableResult func setAttribute(key: String, value: Int) -> Self {
        return setAttribute(key: key, value: AttributeValue.int(value))
    }

    @discardableResult func setAttribute(key: String, value: Double) -> Self {
        return setAttribute(key: key, value: AttributeValue.double(value))
    }

    @discardableResult func setAttribute(key: String, value: Bool) -> Self {
        return setAttribute(key: key, value: AttributeValue.bool(value))
    }
}
