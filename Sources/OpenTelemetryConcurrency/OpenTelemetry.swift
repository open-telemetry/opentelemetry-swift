/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

typealias _OpenTelemetry = OpenTelemetryApi.OpenTelemetry

/// A wrapper type which provides a span builder just like `Tracer`, returns a type of `SpanBuilderBase` to hide APIs on `SpanBuilder` that aren't correctly usable when using a structured concurrency based context manager.
public struct TracerWrapper {
  /// The inner `Tracer` used to construct a span builder. Be careful when accessing this property, as it may make it easier to use API's that don't function properly with your configuration.
  public let inner: Tracer

  public func spanBuilder(spanName: String) -> SpanBuilderBase {
    inner.spanBuilder(spanName: spanName)
  }
}

/// A wrapper type which provides a `Tracer` just like `TracerProvider`, but wraps it in a `TracerWrapper` to hide APIs on `SpanBuilder` that aren't correctly usable when using a structured concurrency based context manager.
public struct TracerProviderWrapper {
  /// The inner `TracerProvider` used to construct a `Tracer`. Be careful when accessing this property, as it may make it easier to use API's that don't function properly with your configuration.
  public let inner: TracerProvider

  public func get(instrumentationName: String,
                  instrumentationVersion: String? = nil,
                  schemaUrl: String? = nil,
                  attributes: [String: AttributeValue]? = nil) -> TracerWrapper {
    TracerWrapper(
      inner: inner
        .get(
          instrumentationName: instrumentationName,
          instrumentationVersion: instrumentationVersion,
          schemaUrl: schemaUrl,
          attributes: attributes
        )
    )
  }
}

/// The main interface for interacting with OpenTelemetry types.
///
/// This type proxies its implementation to the `OpenTelemetryApi.OpenTelemetry` type, wrapping some of the results in new types to hide APIs that will not function correctly when using a context manager based on structured concurrency.
///
/// If you import this module and `OpenTelemetryApi` you will not be able to reference the `OpenTelemetry` type normally, because the names intentionally conflict. You can resolve this error with a typealias
///
/// ```swift
/// import OpenTelemetryApi
/// import OpenTelemetryConcurrency
///
/// // This typealias will be preferred over the name in either package, so you only have to refer to the module name once
/// typealias OpenTelemetry = OpenTelemetryConcurrency.OpenTelemetry
/// ```
public struct OpenTelemetry {
  public static var version: String { _OpenTelemetry.version }

  public static var instance = OpenTelemetry()

  /// Registered tracerProvider or default via DefaultTracerProvider.instance.
  public var tracerProvider: TracerProviderWrapper {
    TracerProviderWrapper(inner: _OpenTelemetry.instance.tracerProvider)
  }

  /// Registered MeterProvider or default via DefaultMeterProvider.instance.
  public var meterProvider: MeterProvider {
    _OpenTelemetry.instance.meterProvider
  }

  public var stableMeterProvider: (any StableMeterProvider)? {
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

  /// On platforms that support the original default context manager, it is prefered over the structured concurrency context manager when initializing OpenTelemetry. Call this method to register the default structured concurrency context manager instead.
  public static func registerDefaultConcurrencyContextManager() {
    _OpenTelemetry.registerContextManager(contextManager: TaskLocalContextManager.instance)
  }

  public static func registerStableMeterProvider(meterProvider: any StableMeterProvider) {
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

  /// Sets `span` as the active span for the duration of the given closure. While the span will no longer be active after the closure exits, this method does **not** end the span. Prefer `SpanBuilderBase.withActiveSpan` which handles starting, activating, and ending the span.
  public func withActiveSpan<T>(_ span: SpanBase, _ operation: () throws -> T) rethrows -> T {
    try contextManager.withCurrentContextValue(forKey: .span, value: span, operation)
  }

  public func withActiveBaggage<T>(_ baggage: Baggage, _ operation: () throws -> T) rethrows -> T {
    try contextManager.withCurrentContextValue(forKey: .baggage, value: baggage, operation)
  }

  /// Sets `span` as the active span for the duration of the given closure. While the span will no longer be active after the closure exits, this method does **not** end the span. Prefer `SpanBuilderBase.withActiveSpan` which handles starting, activating, and ending the span.
  public func withActiveSpan<T>(_ span: SpanBase, _ operation: () async throws -> T) async rethrows -> T {
    try await contextManager.withCurrentContextValue(forKey: .span, value: span, operation)
  }

  public func withActiveBaggage<T>(_ baggage: Baggage, _ operation: () async throws -> T) async rethrows -> T {
    try await contextManager.withCurrentContextValue(forKey: .baggage, value: baggage, operation)
  }
}
