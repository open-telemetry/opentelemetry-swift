/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

#if swift(<5.9)
#error("Swift 5.9 or greater is required for this OpenTelemetryConcurrency")
#else

typealias _OpenTelemetry = OpenTelemetryApi.OpenTelemetry

public struct OpenTelemetry {
    public static var version: String { _OpenTelemetry.version }

    public static var instance = OpenTelemetry()

    /// Registered tracerProvider or default via DefaultTracerProvider.instance.
    public var tracerProvider: TracerProviderBase {
        _OpenTelemetry.instance.tracerProvider
    }

    /// Registered MeterProvider or default via DefaultMeterProvider.instance.
    public var meterProvider: MeterProvider {
        _OpenTelemetry.instance.meterProvider
    }

    public var stableMeterProvider: StableMeterProvider? {
        _OpenTelemetry.instance.stableMeterProvider
    }

    /// Registered LoggerProvider or default via DefaultLoggerProvider.instance.
    public var loggerProvider: LoggerProvider {
        _OpenTelemetry.instance.loggerProvider
    }

    /// registered manager or default via  DefaultBaggageManager.instance.
    public var baggageManager: BaggageManager {
        _OpenTelemetry.instance.baggageManager
    }

    /// registered manager or default via  DefaultBaggageManager.instance.
    public var propagators: ContextPropagators = DefaultContextPropagators(textPropagators: [W3CTraceContextPropagator()], baggagePropagator: W3CBaggagePropagator())

    /// registered manager or default via  DefaultBaggageManager.instance.
    public var contextProvider: OpenTelemetryContextProvider {
        OpenTelemetryContextProvider(contextManager: _OpenTelemetry.instance.contextProvider.contextManager)
    }

    public static func registerDefaultConcurrencyContextManager() {
        _OpenTelemetry.registerContextManager(contextManager: TaskLocalContextManager.instance)
    }

    public static func registerStableMeterProvider(meterProvider: StableMeterProvider) {
        _OpenTelemetry.registerStableMeterProvider(meterProvider: meterProvider)
    }

    public static func registerTracerProvider(tracerProvider: TracerProvider) {
        _OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    public static func registerMeterProvider(meterProvider: MeterProvider) {
        _OpenTelemetry.registerMeterProvider(meterProvider: meterProvider)
    }

    public static func registerLoggerProvider(loggerProvider: LoggerProvider) {
        _OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    }

    public static func registerBaggageManager(baggageManager: BaggageManager) {
        _OpenTelemetry.registerBaggageManager(baggageManager: baggageManager)
    }

    public static func registerPropagators(textPropagators: [TextMapPropagator], baggagePropagator: TextMapBaggagePropagator) {
        _OpenTelemetry.registerPropagators(textPropagators: textPropagators, baggagePropagator: baggagePropagator)
    }

    public static func registerContextManager(contextManager: ContextManager) {
        _OpenTelemetry.registerContextManager(contextManager: contextManager)
    }
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

    public func withActiveSpan<T>(_ span: Span, _ operation: () async throws -> T) async throws -> T {
        try await self.contextManager.withCurrentContextValue(forKey: .span, value: span, operation)
    }

    public func withActiveBaggage<T>(_ baggage: Baggage, _ operation: () async throws -> T) async throws -> T {
        try await self.contextManager.withCurrentContextValue(forKey: .baggage, value: baggage, operation)
    }
}

#endif
