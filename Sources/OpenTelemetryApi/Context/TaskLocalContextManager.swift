/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

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

    public static func removeSpan(span: Span) {
        spanRLock.lock()
        defer { spanRLock.unlock() }
        guard !spans.isEmpty else {
            return
        }
        let spanIndex = spans.lastIndex { span.context.spanId == $0.context.spanId }
        if let index = spanIndex {
            var aux = spans
            aux.remove(at: index)
            _spans = TaskLocal(wrappedValue: aux)
        }
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

    public static func removeBaggage(baggage: Baggage) {
        baggageRLock.lock()
        defer { baggageRLock.unlock() }
        guard !baggages.isEmpty else {
            return
        }
        let baggageIndex = baggages.lastIndex { $0 == baggage  }
        if let index = baggageIndex {
            var aux = baggages
            aux.remove(at: index)
            _baggages = TaskLocal(wrappedValue: aux)
        }
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
                if let span = value as? Span {
                    ContextManagement.removeSpan(span: span)
                }
            case .baggage:
                if let baggage = value as? Baggage {
                    ContextManagement.removeBaggage(baggage: baggage)
                }
        }
    }
}
#endif
