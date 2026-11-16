/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Represents the shared state/config between all Tracers created by the same TracerProvider.
///
/// All mutable state is protected by a read-write lock: configuration is written rarely
/// (setup, registration) but read on every span start, so concurrent readers must never
/// observe a partially applied update such as a mid-replacement `activeSpanProcessor`.
class TracerSharedState {
  private let lock = ReadWriteLock()

  private var _clock: Clock
  private var _idGenerator: IdGenerator
  private var _resource: Resource
  private var _activeSpanLimits: SpanLimits
  private var _sampler: Sampler
  private var _activeSpanProcessor: SpanProcessor
  private var _hasBeenShutdown = false
  private var _registeredSpanProcessors = [SpanProcessor]()

  let launchEnvironmentContext: SpanContext?

  var clock: Clock {
    get { lock.withReaderLock { _clock } }
    set { lock.withWriterLock { _clock = newValue } }
  }

  var idGenerator: IdGenerator {
    get { lock.withReaderLock { _idGenerator } }
    set { lock.withWriterLock { _idGenerator = newValue } }
  }

  var resource: Resource {
    get { lock.withReaderLock { _resource } }
    set { lock.withWriterLock { _resource = newValue } }
  }

  var activeSpanLimits: SpanLimits {
    lock.withReaderLock { _activeSpanLimits }
  }

  var sampler: Sampler {
    lock.withReaderLock { _sampler }
  }

  var activeSpanProcessor: SpanProcessor {
    get { lock.withReaderLock { _activeSpanProcessor } }
    set { lock.withWriterLock { _activeSpanProcessor = newValue } }
  }

  var hasBeenShutdown: Bool {
    lock.withReaderLock { _hasBeenShutdown }
  }

  var registeredSpanProcessors: [SpanProcessor] {
    lock.withReaderLock { _registeredSpanProcessors }
  }

  init(clock: Clock,
       idGenerator: IdGenerator,
       resource: Resource,
       spanLimits: SpanLimits,
       sampler: Sampler,
       spanProcessors: [SpanProcessor]) {
    _clock = clock
    _idGenerator = idGenerator
    _resource = resource
    _activeSpanLimits = spanLimits
    _sampler = sampler
    if spanProcessors.count > 1 {
      _activeSpanProcessor = MultiSpanProcessor(spanProcessors: spanProcessors)
      _registeredSpanProcessors = spanProcessors
    } else if spanProcessors.count == 1 {
      _activeSpanProcessor = spanProcessors[0]
      _registeredSpanProcessors = spanProcessors
    } else {
      _activeSpanProcessor = NoopSpanProcessor()
    }

    /// Recovers explicit parent context from process environment variables, it allows to automatic
    /// trace context propagation to child processes
    let w3cPropagator = W3CTraceContextPropagator()
    let mappingGetter = EnvironmentMappingGetter(innerGetter: EnvironmentGetter())
    launchEnvironmentContext = w3cPropagator.extract(carrier: ProcessInfo.processInfo.environment, getter: mappingGetter)
  }

  /// Adds a new SpanProcessor
  /// - Parameter spanProcessor:  the new SpanProcessor to be added.
  func addSpanProcessor(_ spanProcessor: SpanProcessor) {
    lock.withWriterLock {
      _registeredSpanProcessors.append(spanProcessor)
      if _registeredSpanProcessors.count > 1 {
        _activeSpanProcessor = MultiSpanProcessor(spanProcessors: _registeredSpanProcessors)
      } else {
        _activeSpanProcessor = _registeredSpanProcessors[0]
      }
    }
  }

  /// Stops tracing, including shutting down processors and set to true isStopped.
  func stop() {
    // Claim shutdown under the lock, but call the processor outside it:
    // shutdown() can block on export and must not stall readers.
    var processor: SpanProcessor? = lock.withWriterLock {
      if _hasBeenShutdown {
        return nil
      }
      _hasBeenShutdown = true
      return _activeSpanProcessor
    }
    processor?.shutdown()
  }

  func setActiveSpanLimits(_ activeSpanLimits: SpanLimits) {
    lock.withWriterLock { _activeSpanLimits = activeSpanLimits }
  }

  func setSampler(_ sampler: Sampler) {
    lock.withWriterLock { _sampler = sampler }
  }

  // Sets the global sampler probability
  func setSamplerProbability(samplerProbability: Double) {
    if samplerProbability >= 1 {
      return setSampler(Samplers.alwaysOn)
    } else if samplerProbability <= 0 {
      return setSampler(Samplers.alwaysOff)
    } else {
      return setSampler(Samplers.traceIdRatio(ratio: samplerProbability))
    }
  }

  private struct EnvironmentGetter: Getter {
    func get(carrier: [String: String], key: String) -> [String]? {
      if let value = carrier[key] {
        return [value]
      }
      return nil
    }
  }
}
