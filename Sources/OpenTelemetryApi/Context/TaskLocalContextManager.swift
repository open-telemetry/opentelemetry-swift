/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(_Concurrency)
@available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
enum ContextManagement {
    @TaskLocal
    static var span: Span?
    public static func setSpan(wrappedSpan: TaskLocal<Span?>) {
        _span = wrappedSpan
    }

    @TaskLocal
    static var baggage: Baggage?
    public static func setBaggage(wrappedBaggage: TaskLocal<Baggage?>) {
        _baggage = wrappedBaggage
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
class TaskLocalContextManager: ContextManager {
    static let instance = TaskLocalContextManager()

    func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        switch key {
            case .span:
                return ContextManagement.span
            case .baggage:
                return ContextManagement.baggage
        }
    }

    func setCurrentContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        switch key {
            case .span:
                if let span = value as? Span {
                    ContextManagement.setSpan(wrappedSpan: TaskLocal(wrappedValue: span))
                }
            case .baggage:
                if let baggage = value as? Baggage {
                    ContextManagement.setBaggage(wrappedBaggage: TaskLocal(wrappedValue: baggage))
                }
        }
    }

    func removeContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        switch key {
            case .span:
                ContextManagement.setSpan(wrappedSpan: TaskLocal(wrappedValue: nil))
            case .baggage:
                ContextManagement.setBaggage(wrappedBaggage: TaskLocal(wrappedValue: nil))
        }
    }
}
#endif
