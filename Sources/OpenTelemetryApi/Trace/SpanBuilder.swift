/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A base protocol for `SpanBuilder` which encapsulates all of the functionality that is correct in both imperative and structured APIs. Functionality which is only guarenteed to work in the imperative APIs exists on `SpanBuilder`.
///
/// - Warning: It is never correct to only implement `SpanBuilderBase`, `SpanBuilder` should always be implemented for any span builder type as well.
public protocol SpanBuilderBase: AnyObject {
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

    /// Starts a new Span and makes it active for the duration of the passed closure. The span will be ended before this method returns.
    func withActiveSpan<T>(_ operation: (any SpanBase) throws -> T) rethrows -> T

#if canImport(_Concurrency)
    /// Starts a new Span and makes it active for the duration of the passed closure. The span will be ended before this method returns.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func withActiveSpan<T>(_ operation: (any SpanBase) async throws -> T) async rethrows -> T
#endif

    /// Starts a new Span.
    ///
    /// Users must manually call Span.end() to end this Span
    ///
    /// Does not install the newly created Span to the current Context.
    func startSpan() -> Span

    /// Starts a new Span. The span will be ended before this method returns.
    func withStartedSpan<T>(_ operation: (any SpanBase) throws -> T) rethrows -> T

#if canImport(_Concurrency)
    /// Starts a new Span. The span will be ended before this method returns.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func withStartedSpan<T>(_ operation: (any SpanBase) async throws -> T) async rethrows -> T
#endif
}

public protocol SpanBuilder: SpanBuilderBase {
    /// Sets the Span as the active Span in the current context when started.
    /// - Parameter active: If the span will be set as the activeSpan
    @discardableResult func setActive(_ active: Bool) -> Self
}

public extension SpanBuilderBase {
    func withStartedSpan<T>(_ operation: (any SpanBase) throws -> T) rethrows -> T {
        let span = self.startSpan()
        defer {
            span.end()
        }

        return try operation(span)
    }

#if canImport(_Concurrency)
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func withStartedSpan<T>(_ operation: (any SpanBase) async throws -> T) async rethrows -> T {
        let span = self.startSpan()
        defer {
            span.end()
        }

        return try await operation(span)
    }
#endif

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
