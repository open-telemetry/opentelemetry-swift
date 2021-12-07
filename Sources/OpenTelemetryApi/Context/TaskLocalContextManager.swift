/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(_Concurrency)
#if swift(>=5.5.2)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
enum ContextManagement {
    static let spanRLock = NSRecursiveLock()
    static let baggageRLock = NSRecursiveLock()

    @TaskLocal
    private static var spans = [Span]()

    public static func getSpan() -> Span? {
        spanRLock.lock()
        defer { spanRLock.unlock() }
        return spans.last
    }

    public static func setSpan(span: Span) {
        spanRLock.lock()
        defer { spanRLock.unlock() }
        var aux = spans
        aux.append(span)
        _spans = TaskLocal(wrappedValue: aux)
    }

    public static func removeSpan() {
        spanRLock.lock()
        defer { spanRLock.unlock() }
        guard !spans.isEmpty else {
            return
        }
        var aux = spans
        aux.removeLast()
        _spans = TaskLocal(wrappedValue: aux)
    }

    @TaskLocal
    private static var baggages = [Baggage]()

    public static func getBaggage() -> Baggage? {
        baggageRLock.lock()
        defer { baggageRLock.unlock() }
        return baggages.last
    }

    public static func setBaggage(baggage: Baggage) {
        baggageRLock.lock()
        defer { baggageRLock.unlock() }
        var aux = baggages
        aux.append(baggage)
        _baggages = TaskLocal(wrappedValue: aux)
    }

    public static func removeBaggage() {
        baggageRLock.lock()
        defer { baggageRLock.unlock() }
        guard !baggages.isEmpty else {
            return
        }
        var aux = baggages
        aux.removeLast()
        _baggages = TaskLocal(wrappedValue: aux)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
class TaskLocalContextManager: ContextManager {
    static let instance = TaskLocalContextManager()

    func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        switch key {
            case .span:
                return ContextManagement.getSpan()
            case .baggage:
                return ContextManagement.getBaggage()
        }
    }

    func setCurrentContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        switch key {
            case .span:
                if let span = value as? Span {
                    ContextManagement.setSpan(span: span)
                }
            case .baggage:
                if let baggage = value as? Baggage {
                    ContextManagement.setBaggage(baggage: baggage)
                }
        }
    }

    func removeContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        switch key {
            case .span:
                ContextManagement.removeSpan()
            case .baggage:
                ContextManagement.removeBaggage()
        }
    }
}
#else
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
#endif
