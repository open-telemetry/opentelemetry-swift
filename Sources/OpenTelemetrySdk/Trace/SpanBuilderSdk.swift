/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// SpanBuilderSdk is SDK implementation of SpanBuilder.
class SpanBuilderSdk: SpanBuilder {
  private enum ParentType {
    case currentSpan
    case explicitParent
    case explicitRemoteParent
    case noParent
  }

  static let traceOptionsSampled = TraceFlags().settingIsSampled(true)
  static let traceOptionsNotSampled = TraceFlags().settingIsSampled(false)

  private var spanName: String
  private var instrumentationScopeInfo: InstrumentationScopeInfo
  private var tracerSharedState: TracerSharedState
  private var spanLimits: SpanLimits

  private var parent: Span?
  private var remoteParent: SpanContext?
  private var spanKind = SpanKind.internal
  private var attributes: AttributesDictionary
  private var links = [SpanData.Link]()
  private var totalNumberOfLinksAdded: Int = 0
  private var parentType: ParentType = .currentSpan

  private var startAsActive: Bool = false

  private var startTime: Date?

  init(spanName: String,
       instrumentationScopeInfo: InstrumentationScopeInfo,
       tracerSharedState: TracerSharedState,
       spanLimits: SpanLimits) {
    self.spanName = spanName
    self.instrumentationScopeInfo = instrumentationScopeInfo
    self.tracerSharedState = tracerSharedState
    self.spanLimits = spanLimits
    attributes = AttributesDictionary(capacity: spanLimits.attributeCountLimit)
  }

  @discardableResult func setParent(_ parent: Span) -> Self {
    self.parent = parent
    remoteParent = nil
    parentType = .explicitParent
    return self
  }

  @discardableResult func setParent(_ parent: SpanContext) -> Self {
    remoteParent = parent
    self.parent = nil
    parentType = .explicitRemoteParent
    return self
  }

  @discardableResult func setNoParent() -> Self {
    parentType = .noParent
    remoteParent = nil
    parent = nil
    return self
  }

  @discardableResult func addLink(spanContext: SpanContext) -> Self {
    return addLink(SpanData.Link(context: spanContext))
  }

  @discardableResult func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self {
    return addLink(SpanData.Link(context: spanContext, attributes: attributes))
  }

  @discardableResult func addLink(_ link: SpanData.Link) -> Self {
    totalNumberOfLinksAdded += 1
    if links.count >= spanLimits.linkCountLimit {
      return self
    }
    links.append(link)
    return self
  }

  @discardableResult func setAttribute(key: String, value: AttributeValue) -> Self {
    attributes.updateValue(value: value, forKey: key)
    return self
  }

  @discardableResult func setSpanKind(spanKind: SpanKind) -> Self {
    self.spanKind = spanKind
    return self
  }

  @discardableResult func setStartTime(time: Date) -> Self {
    startTime = time
    return self
  }

  @discardableResult func setActive(_ active: Bool) -> Self {
    startAsActive = active
    return self
  }

  func prepareSpan() -> Span {
    var parentContext = getParentContext(parentType: parentType, explicitParent: parent, remoteParent: remoteParent)
    let traceId: TraceId
    let spanId = tracerSharedState.idGenerator.generateSpanId()
    var traceState = TraceState()

    if parentContext?.isValid ?? false {
      traceId = parentContext!.traceId
      traceState = parentContext!.traceState
    } else {
      traceId = tracerSharedState.idGenerator.generateTraceId()
      parentContext = nil
    }

    let samplingDecision = tracerSharedState.sampler.shouldSample(parentContext: parentContext,
                                                                  traceId: traceId,
                                                                  name: spanName,
                                                                  kind: spanKind,
                                                                  attributes: attributes.attributes,
                                                                  parentLinks: links)

    let spanContext = SpanContext.create(traceId: traceId,
                                         spanId: spanId,
                                         traceFlags: TraceFlags().settingIsSampled(samplingDecision.isSampled),
                                         traceState: traceState)

    if !samplingDecision.isSampled {
      return DefaultTracer.instance.spanBuilder(spanName: spanName).startSpan()
    }

    attributes.updateValues(attributes: samplingDecision.attributes)

    return SpanSdk.startSpan(context: spanContext,
                                              name: spanName,
                                              instrumentationScopeInfo: instrumentationScopeInfo,
                                              kind: spanKind,
                                              parentContext: parentContext,
                                              hasRemoteParent: parentContext?.isRemote ?? false,
                                              spanLimits: spanLimits,
                                              spanProcessor: tracerSharedState.activeSpanProcessor,
                                              clock: SpanBuilderSdk.getClock(parent: SpanBuilderSdk.getParentSpan(parentType: parentType, explicitParent: parent), clock: tracerSharedState.clock),
                                              resource: tracerSharedState.resource,
                                              attributes: attributes,
                                              links: links,
                                              totalRecordedLinks: totalNumberOfLinksAdded,
                                              startTime: startTime)
  }

  func startSpan() -> Span {
    let createdSpan = prepareSpan()

    if startAsActive {
      OpenTelemetry.instance.contextProvider.setActiveSpan(createdSpan)
    }
    return createdSpan
  }

  public func withActiveSpan<T>(_ operation: (any SpanBase) throws -> T) rethrows -> T {
    let createdSpan = prepareSpan()
    defer {
      createdSpan.end()
    }

    return try OpenTelemetry.instance.contextProvider.withActiveSpan(createdSpan) {
      try operation(createdSpan)
    }
  }

  #if canImport(_Concurrency)
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveSpan<T>(_ operation: (any SpanBase) async throws -> T) async rethrows -> T {
      let createdSpan = prepareSpan()
      defer {
        createdSpan.end()
      }

      return try await OpenTelemetry.instance.contextProvider.withActiveSpan(createdSpan) {
        try await operation(createdSpan)
      }
    }
  #endif

  private static func getClock(parent: Span?, clock: Clock) -> Clock {
    if let parentSpanSdk = parent as? SpanSdk {
      return parentSpanSdk.clock
    } else {
      return MonotonicClock(clock: clock)
    }
  }

  private func getParentContext(parentType: ParentType, explicitParent: Span?, remoteParent: SpanContext?) -> SpanContext? {
    let currentSpan = OpenTelemetry.instance.contextProvider.activeSpan

    let parentContext: SpanContext? = switch parentType {
    case .noParent:
      nil
    case .currentSpan:
      currentSpan?.context
    case .explicitParent:
      explicitParent?.context
    case .explicitRemoteParent:
      remoteParent
    }

    return parentContext ?? tracerSharedState.launchEnvironmentContext
  }

  private static func getParentSpan(parentType: ParentType, explicitParent: Span?) -> Span? {
    switch parentType {
    case .currentSpan:
      return OpenTelemetry.instance.contextProvider.activeSpan
    case .explicitParent:
      return explicitParent
    default:
      return nil
    }
  }
}
