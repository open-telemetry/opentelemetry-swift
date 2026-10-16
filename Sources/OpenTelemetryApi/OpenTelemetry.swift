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
public struct OpenTelemetry: Sendable {
  public static let version = "v1.38.0"

  public static let instance = OpenTelemetry()

  /// Registered tracerProvider or default via DefaultTracerProvider.instance.
  public var tracerProvider: TracerProvider {
    OpenTelemetryStorage.instance.tracerProvider
  }

  /// Registered MeterProvider or default via DefaultMeterProvider.instance.
  public var meterProvider: any MeterProvider {
    OpenTelemetryStorage.instance.meterProvider
  }

  /// Registered LoggerProvider or default via DefaultLoggerProvider.instance.
  public var loggerProvider: LoggerProvider {
    OpenTelemetryStorage.instance.loggerProvider
  }

  /// registered manager or default via  DefaultBaggageManager.instance.
  public var baggageManager: BaggageManager {
    OpenTelemetryStorage.instance.baggageManager
  }

  /// registered manager or default via  DefaultBaggageManager.instance.
  public var propagators: ContextPropagators {
    OpenTelemetryStorage.instance.propagators
  }

  /// registered manager or default via  DefaultBaggageManager.instance.
  public var contextProvider: OpenTelemetryContextProvider {
    OpenTelemetryStorage.instance.contextProvider
  }

  /// Allow customizing how warnings and informative messages about usages of OpenTelemetry are relayed back to the developer.
  public var feedbackHandler: ((String) -> Void)? {
    OpenTelemetryStorage.instance.feedbackHandler
  }

  private init() {}

  @available(*, deprecated, renamed: "registerMeterProvider")
  public static func registerStableMeterProvider(meterProvider: any MeterProvider) {
    Self.registerMeterProvider(meterProvider: meterProvider)
  }

  public static func registerMeterProvider(
    meterProvider: any MeterProvider
  ) {
    OpenTelemetryStorage.instance.setMeterProvider(meterProvider)
  }

  public static func registerTracerProvider(tracerProvider: TracerProvider) {
    OpenTelemetryStorage.instance.setTracerProvider(tracerProvider)
  }

  public static func registerLoggerProvider(loggerProvider: LoggerProvider) {
    OpenTelemetryStorage.instance.setLoggerProvider(loggerProvider)
  }

  public static func registerBaggageManager(baggageManager: BaggageManager) {
    OpenTelemetryStorage.instance.setBaggageManager(baggageManager)
  }

  public static func registerPropagators(textPropagators: [TextMapPropagator],
                                         baggagePropagator: TextMapBaggagePropagator) {
    OpenTelemetryStorage.instance.setPropagators(
      DefaultContextPropagators(textPropagators: textPropagators, baggagePropagator: baggagePropagator)
    )
  }

  public static func registerContextManager(contextManager: ContextManager) {
    OpenTelemetryStorage.instance.setContextManager(contextManager)
  }

  /// Register a function to be called when the library has warnings or informative messages to relay back to the developer
  public static func registerFeedbackHandler(
    _ handler: @escaping (String) -> Void
  ) {
    OpenTelemetryStorage.instance.setFeedbackHandler(handler)
  }

  /// A utility method for testing which sets the context manager for the duration of the closure, and then reverts it before the method returns
  static func withContextManager<T>(_ manager: ContextManager, _ operation: () throws -> T) rethrows -> T {
    let old = OpenTelemetryStorage.instance.getContextManager()
    defer {
      self.registerContextManager(contextManager: old)
    }

    registerContextManager(contextManager: manager)

    return try operation()
  }
}


/// Thread-safe storage for OpenTelemetry singleton state.
///
/// All mutable state is protected by a read-write lock, allowing concurrent
/// readers while serializing writes (registration calls).
private final class OpenTelemetryStorage: @unchecked Sendable {
  static let instance = OpenTelemetryStorage()

  private let lock = ReadWriteLock()

  private var _tracerProvider: TracerProvider
  private var _meterProvider: any MeterProvider
  private var _loggerProvider: LoggerProvider
  private var _baggageManager: BaggageManager
  private var _propagators: ContextPropagators
  private var _contextProvider: OpenTelemetryContextProvider
  private var _feedbackHandler: ((String) -> Void)?

  private init() {
    _meterProvider = DefaultMeterProvider.instance
    _tracerProvider = DefaultTracerProvider.instance
    _loggerProvider = DefaultLoggerProvider.instance
    _baggageManager = DefaultBaggageManager.instance
    _propagators = DefaultContextPropagators(
      textPropagators: [W3CTraceContextPropagator()],
      baggagePropagator: W3CBaggagePropagator()
    )
    #if canImport(os.activity)
      let manager = ActivityContextManager.instance
    #elseif canImport(_Concurrency)
      let manager = TaskLocalContextManager.instance
    #else
      #error("No default ContextManager is supported on the target platform")
    #endif
    _contextProvider = OpenTelemetryContextProvider(contextManager: manager)

    #if canImport(os.log)
      _feedbackHandler = { message in
        os_log("%{public}s", message)
      }
    #endif
  }

  // MARK: - Thread-safe read accessors

  var tracerProvider: TracerProvider {
    lock.withReaderLock { _tracerProvider }
  }

  var meterProvider: any MeterProvider {
    lock.withReaderLock { _meterProvider }
  }

  var loggerProvider: LoggerProvider {
    lock.withReaderLock { _loggerProvider }
  }

  var baggageManager: BaggageManager {
    lock.withReaderLock { _baggageManager }
  }

  var propagators: ContextPropagators {
    lock.withReaderLock { _propagators }
  }

  var contextProvider: OpenTelemetryContextProvider {
    lock.withReaderLock { _contextProvider }
  }

  var feedbackHandler: ((String) -> Void)? {
    lock.withReaderLock { _feedbackHandler }
  }

  // MARK: - Thread-safe write accessors

  func setTracerProvider(_ provider: TracerProvider) {
    lock.withWriterLock { _tracerProvider = provider }
  }

  func setMeterProvider(_ provider: any MeterProvider) {
    lock.withWriterLock { _meterProvider = provider }
  }

  func setLoggerProvider(_ provider: LoggerProvider) {
    lock.withWriterLock { _loggerProvider = provider }
  }

  func setBaggageManager(_ manager: BaggageManager) {
    lock.withWriterLock { _baggageManager = manager }
  }

  func setPropagators(_ propagators: ContextPropagators) {
    lock.withWriterLock { _propagators = propagators }
  }

  func setContextManager(_ manager: ContextManager) {
    lock.withWriterLock { _contextProvider.contextManager = manager }
  }

  func getContextManager() -> ContextManager {
    lock.withReaderLock { _contextProvider.contextManager }
  }

  func setFeedbackHandler(_ handler: @escaping (String) -> Void) {
    lock.withWriterLock { _feedbackHandler = handler }
  }
}