/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Keys used by Opentelemetry to store values in the Context
public enum OpenTelemetryContextKeys: String {
    case span
    case baggage
}

public struct OpenTelemetryContextProvider {
#if swift(>=5.9)
    package var contextManager: ContextManager
#else
    var contextManager: ContextManager
#endif

    /// Returns the Span from the current context
    public var activeSpan: Span? {
        return contextManager.getCurrentContextValue(forKey: .span) as? Span
    }

    /// Returns the Baggage from the current context
    public var activeBaggage: Baggage? {
        return contextManager.getCurrentContextValue(forKey: OpenTelemetryContextKeys.baggage) as? Baggage
    }

    /// Sets the span as the activeSpan for the current context
    /// - Parameter span: the Span to be set to the current context
    public func setActiveSpan(_ span: Span) {
        contextManager.setCurrentContextValue(forKey: OpenTelemetryContextKeys.span, value: span)
    }

    /// Sets the span as the activeSpan for the current context
    /// - Parameter baggage: the Correlation Context to be set to the current context
    public func setActiveBaggage(_ baggage: Baggage) {
        contextManager.setCurrentContextValue(forKey: OpenTelemetryContextKeys.baggage, value: baggage)
    }

    public func removeContextForSpan(_ span: Span) {
        contextManager.removeContextValue(forKey: OpenTelemetryContextKeys.span, value: span)
    }

    public func removeContextForBaggage(_ baggage: Baggage) {
        contextManager.removeContextValue(forKey: OpenTelemetryContextKeys.baggage, value: baggage)
    }

    /// Sets `span` as the active span for the duration of the given closure.
    /// While the span will no longer be active after the closure exits, this method does **not** end the span.
    /// Prefer `SpanBuilderBase.withActiveSpan` which handles starting, activating, and ending the span.
    public func withActiveSpan<T>(_ span: SpanBase, _ operation: () throws -> T) rethrows -> T {
        try contextManager.withCurrentContextValue(forKey: .span, value: span, operation)
    }

    public func withActiveBaggage<T>(_ span: Baggage, _ operation: () throws -> T) rethrows -> T {
        try contextManager.withCurrentContextValue(forKey: .baggage, value: span, operation)
    }

#if canImport(_Concurrency)
    /// Sets `span` as the active span for the duration of the given closure.
    /// While the span will no longer be active after the closure exits, this method does **not** end the span.
    /// Prefer `SpanBuilderBase.withActiveSpan` which handles starting, activating, and ending the span.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveSpan<T>(_ span: SpanBase, _ operation: () async throws -> T) async rethrows -> T {
        try await contextManager.withCurrentContextValue(forKey: .span, value: span, operation)
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveBaggage<T>(_ span: Baggage, _ operation: () async throws -> T) async rethrows -> T {
        try await contextManager.withCurrentContextValue(forKey: .baggage, value: span, operation)
    }
#endif
}
