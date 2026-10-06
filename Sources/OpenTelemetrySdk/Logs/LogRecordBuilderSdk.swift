//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class LogRecordBuilderSdk: EventBuilder {
  private var sharedState: LoggerSharedState
  private var limits: LogLimits
  private var instrumentationScope: InstrumentationScopeInfo
  private var includeSpanContext: Bool
  private var timestamp: Date?
  private var observedTimestamp: Date?
  private var body: AttributeValue?
  private var severity: Severity?
  private var attributes: AttributesDictionary
  private var spanContext: SpanContext?
  private var eventName: String?

  init(sharedState: LoggerSharedState, instrumentationScope: InstrumentationScopeInfo,
       includeSpanContext: Bool) {
    self.sharedState = sharedState
    limits = sharedState.logLimits
    self.includeSpanContext = includeSpanContext
    self.instrumentationScope = instrumentationScope
    attributes = AttributesDictionary(capacity: sharedState.logLimits.maxAttributeCount,
                                      valueLengthLimit: sharedState.logLimits.maxAttributeLength)
  }

  public func setTimestamp(_ timestamp: Date) -> Self {
    self.timestamp = timestamp
    return self
  }

  public func setObservedTimestamp(_ observed: Date) -> Self {
    observedTimestamp = observed
    return self
  }

  public func setSpanContext(_ context: OpenTelemetryApi.SpanContext) -> Self {
    spanContext = context

    return self
  }

  public func setSeverity(_ severity: OpenTelemetryApi.Severity) -> Self {
    self.severity = severity
    return self
  }

  public func setBody(_ body: AttributeValue) -> Self {
    self.body = body
    return self
  }

  public func setAttributes(_ attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
    self.attributes.updateValues(attributes: attributes)
    return self
  }

  public func setData(_ attributes: [String: AttributeValue]) -> Self {
    self.attributes["event.data"] = AttributeValue(AttributeSet(labels: attributes))
    return self
  }
  
  public func setEventName(_ eventName: String) -> Self {
    self.eventName = eventName
    return self
  }

  public func emit() {
    if spanContext == nil, includeSpanContext {
      spanContext = OpenTelemetry.instance.contextProvider.activeSpan?.context
    }

    sharedState.activeLogRecordProcessor.onEmit(
      logRecord: ReadableLogRecord(resource: sharedState.resource,
                                   instrumentationScopeInfo: instrumentationScope,
                                   timestamp: timestamp ?? sharedState.clock.now,
                                   observedTimestamp: observedTimestamp ?? sharedState.clock.now,
                                   spanContext: spanContext,
                                   severity: severity,
                                   body: body,
                                   attributes: attributes.attributesCopy(),
                                   eventName: eventName))
  }
}
