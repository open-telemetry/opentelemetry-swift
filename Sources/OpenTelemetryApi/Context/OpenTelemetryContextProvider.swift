/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import os.activity

/// Keys used by Opentelemetry to store values in the Context
public enum OpenTelemetryContextKeys: String {
    case span
    case baggage
}

public struct OpenTelemetryContextProvider {
    var contextManager: ContextManager

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
}
