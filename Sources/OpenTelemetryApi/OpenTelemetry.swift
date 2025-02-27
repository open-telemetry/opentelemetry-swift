/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(os.log)
  import os.log
#endif

/// This class provides a static global accessor for telemetry objects Tracer, Meter
///  and BaggageManager.
///  The telemetry objects are lazy-loaded singletons resolved via ServiceLoader mechanism.
public struct OpenTelemetry {
  public static var version = "v1.21.0"

  public static var instance = OpenTelemetry()

  /// Registered tracerProvider or default via DefaultTracerProvider.instance.
  public private(set) var tracerProvider: TracerProvider

  /// Registered MeterProvider or default via DefaultMeterProvider.instance.
  public private(set) var meterProvider: MeterProvider

  public private(set) var stableMeterProvider: StableMeterProvider?

  /// Registered LoggerProvider or default via DefaultLoggerProvider.instance.
  public private(set) var loggerProvider: LoggerProvider

  /// registered manager or default via  DefaultBaggageManager.instance.
  public private(set) var baggageManager: BaggageManager

  /// registered manager or default via  DefaultBaggageManager.instance.
  public private(set) var propagators: ContextPropagators =
    DefaultContextPropagators(textPropagators: [W3CTraceContextPropagator()],
                              baggagePropagator: W3CBaggagePropagator())

  /// registered manager or default via  DefaultBaggageManager.instance.
  public private(set) var contextProvider: OpenTelemetryContextProvider

  /// Allow customizing how warnings and informative messages about usages of OpenTelemetry are relayed back to the developer.
  public private(set) var feedbackHandler: ((String) -> Void)?

  private init() {
    stableMeterProvider = nil
    tracerProvider = DefaultTracerProvider.instance
    meterProvider = DefaultMeterProvider.instance
    loggerProvider = DefaultLoggerProvider.instance
    baggageManager = DefaultBaggageManager.instance
    #if canImport(os.activity)
      let manager = ActivityContextManager.instance
    #elseif canImport(_Concurrency)
      let manager = TaskLocalContextManager.instance
    #else
      #error("No default ContextManager is supported on the target platform")
    #endif
    contextProvider = OpenTelemetryContextProvider(contextManager: manager)

    #if canImport(os.log)
      feedbackHandler = { message in
        os_log("%{public}s", message)
      }
    #endif
  }

  public static func registerStableMeterProvider(
    meterProvider: StableMeterProvider
  ) {
    instance.stableMeterProvider = meterProvider
  }

  public static func registerTracerProvider(tracerProvider: TracerProvider) {
    instance.tracerProvider = tracerProvider
  }

  @available(*, deprecated, message: "Use registerStableMeterProvider instead.")
  public static func registerMeterProvider(meterProvider: MeterProvider) {
    instance.meterProvider = meterProvider
  }

  public static func registerLoggerProvider(loggerProvider: LoggerProvider) {
    instance.loggerProvider = loggerProvider
  }

  public static func registerBaggageManager(baggageManager: BaggageManager) {
    instance.baggageManager = baggageManager
  }

  public static func registerPropagators(textPropagators: [TextMapPropagator],
                                         baggagePropagator: TextMapBaggagePropagator) {
    instance.propagators = DefaultContextPropagators(textPropagators: textPropagators, baggagePropagator: baggagePropagator)
  }

  public static func registerContextManager(contextManager: ContextManager) {
    instance.contextProvider.contextManager = contextManager
  }

  /// Register a function to be called when the library has warnings or informative messages to relay back to the developer
  public static func registerFeedbackHandler(
    _ handler: @escaping (String) -> Void
  ) {
    instance.feedbackHandler = handler
  }

  /// A utility method for testing which sets the context manager for the duration of the closure, and then reverts it before the method returns
  static func withContextManager<T>(_ manager: ContextManager, _ operation: () throws -> T) rethrows -> T {
    let old = instance.contextProvider.contextManager
    defer {
      self.registerContextManager(contextManager: old)
    }

    registerContextManager(contextManager: manager)

    return try operation()
  }
}
