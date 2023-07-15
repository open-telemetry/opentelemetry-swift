//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import ServiceContextModule

/// A context manager based on the `ServiceContext` abstraction, which uses Task local values.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class ServiceContextManager: ContextManager {
    public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        switch key {
        case .baggage:
            return ServiceContext.current?.openTelemetryBaggage
        case .span:
            return ServiceContext.current?.openTelemetrySpan
        }
    }

    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () throws -> T) rethrows -> T {
        var ctx = ServiceContext.current ?? .topLevel
        ctx.apply(key: key, value: value)

        return try ServiceContext.$current.withValue(ctx, operation: action)
    }

    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () async throws -> T) async rethrows -> T {
        var ctx = ServiceContext.current ?? .topLevel
        ctx.apply(key: key, value: value)

        return try await ServiceContext.$current.withValue(ctx, operation: action)
    }
}

extension ServiceContext {
    struct SpanKey: ServiceContextKey {
        public typealias Value = Span

        public static var nameOverride: String? {
            "Span"
        }
    }

    struct BaggageKey: ServiceContextKey {
        public typealias Value = Baggage

        public static var nameOverride: String? {
            "Baggage"
        }
    }

    mutating func apply(key: OpenTelemetryContextKeys, value: AnyObject) {
        switch key {
        case .baggage:
            guard let baggage = value as? Baggage else {
                fatalError("Key OpenTelemetryContextKeys.baggage requires a value of type Baggage")
            }

            self.openTelemetryBaggage = baggage

        case .span:
            guard let span = value as? Span else {
                fatalError("Key OpenTelemetryContextKeys.span requires a value of type Span")
            }

            self.openTelemetrySpan = span
        }
    }

    public var openTelemetrySpan: Span? {
        get {
            self[SpanKey.self]
        }

        set {
            self[SpanKey.self] = newValue
        }
    }

    public var openTelemetryBaggage: Baggage? {
        get {
            self[BaggageKey.self]
        }

        set {
            self[BaggageKey.self] = newValue
        }
    }
}
