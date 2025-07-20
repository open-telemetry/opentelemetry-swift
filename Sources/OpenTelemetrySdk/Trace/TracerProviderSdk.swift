/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class TracerProviderSdk: TracerProvider {
  private let tracerLock: ReadWriteLock = .init()
  private var tracerProvider = [InstrumentationScopeInfo: TracerSdk]()
  var sharedState: TracerSharedState
  static let emptyName = "unknown"

  /// Returns a new TracerProviderSdk with default Clock, IdGenerator and Resource.
  public init(clock: Clock = MillisClock(),
              idGenerator: IdGenerator = RandomIdGenerator(),
              resource: Resource = EnvVarResource.get(),
              spanLimits: SpanLimits = SpanLimits(),
              sampler: Sampler = Samplers.parentBased(root: Samplers.alwaysOn),
              spanProcessors: [SpanProcessor] = []) {
    sharedState = TracerSharedState(clock: clock,
                                    idGenerator: idGenerator,
                                    resource: resource,
                                    spanLimits: spanLimits,
                                    sampler: sampler,
                                    spanProcessors: spanProcessors)
  }

  public func get(instrumentationName: String, instrumentationVersion: String? = nil, schemaUrl: String? = nil, attributes: [String: AttributeValue]? = nil) -> Tracer {
    if sharedState.hasBeenShutdown {
      return DefaultTracer.instance
    }

    var instrumentationName = instrumentationName
    if instrumentationName.isEmpty {
      // Per the spec, empty is "invalid"
      print("Tracer requested without instrumentation name.")
      instrumentationName = TracerProviderSdk.emptyName
    }
    let instrumentationScopeInfo = InstrumentationScopeInfo(
      name: instrumentationName,
      version: instrumentationVersion,
      schemaUrl: schemaUrl,
      attributes: attributes
    )

    let existingTracer = tracerLock.withReaderLock {
      tracerProvider[instrumentationScopeInfo]
    }
    if let existingTracer {
      return existingTracer
    }

    let tracer = TracerSdk(sharedState: sharedState, instrumentationScopeInfo: instrumentationScopeInfo)
    tracerLock.withWriterLock {
      tracerProvider[instrumentationScopeInfo] = tracer
    }
    return tracer
  }

  /// Returns the active Clock.
  public func getActiveClock() -> Clock {
    return sharedState.clock
  }

  /// Updates the active Clock.
  public func updateActiveClock(_ newClock: Clock) {
    sharedState.clock = newClock
  }

  /// Returns the active IdGenerator.
  public func getActiveIdGenerator() -> IdGenerator {
    return sharedState.idGenerator
  }

  /// Updates the active IdGenerator.
  public func updateActiveIdGenerator(_ newGenerator: IdGenerator) {
    sharedState.idGenerator = newGenerator
  }

  /// Returns the active Resource.
  public func getActiveResource() -> Resource {
    return sharedState.resource
  }

  /// Updates the active Resource.
  public func updateActiveResource(_ newResource: Resource) {
    sharedState.resource = newResource
  }

  /// Returns the active SpanLimits.
  public func getActiveSpanLimits() -> SpanLimits {
    return sharedState.activeSpanLimits
  }

  /// Updates the active SpanLimits.
  public func updateActiveSpanLimits(_ spanLimits: SpanLimits) {
    sharedState.setActiveSpanLimits(spanLimits)
  }

  /// Returns the active Sampler.
  public func getActiveSampler() -> Sampler {
    return sharedState.sampler
  }

  /// Updates the active Sampler.
  public func updateActiveSampler(_ newSampler: Sampler) {
    sharedState.setSampler(newSampler)
  }

  /// Returns the active SpanProcessors.
  public func getActiveSpanProcessors() -> [SpanProcessor] {
    if let processor = sharedState.activeSpanProcessor as? MultiSpanProcessor {
      return processor.spanProcessorsAll
    } else {
      return [sharedState.activeSpanProcessor]
    }
  }

  /// Adds a new SpanProcessor to this TracerProvider.
  /// Any registered processor cause overhead, consider to use an async/batch processor especially
  /// for span exporting, and export to multiple backends using the MultiSpanExporter
  /// - Parameter spanProcessor: the new SpanProcessor to be added.
  public func addSpanProcessor(_ spanProcessor: SpanProcessor) {
    sharedState.addSpanProcessor(spanProcessor)
  }

  /// Removes all SpanProcessors from this provider
  public func resetSpanProcessors() {
    sharedState.activeSpanProcessor = NoopSpanProcessor()
  }

  /// Attempts to stop all the activity for this Tracer. Calls SpanProcessor.shutdown()
  /// for all registered SpanProcessors.
  /// This operation may block until all the Spans are processed. Must be called before turning
  /// off the main application to ensure all data are processed and exported.
  /// After this is called all the newly created Spanss will be no-op.
  public func shutdown() {
    if sharedState.hasBeenShutdown {
      return
    }
    sharedState.stop()
  }

  /// Requests the active span processor to process all span events that have not yet been processed.
  public func forceFlush(timeout: TimeInterval? = nil) {
    sharedState.activeSpanProcessor.forceFlush(timeout: timeout)
  }
}
