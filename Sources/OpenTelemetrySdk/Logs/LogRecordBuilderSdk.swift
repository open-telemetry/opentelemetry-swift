//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


public class LogRecordBuilderSdk : EventBuilder {

    
    
    private var sharedState : LoggerSharedState
    private var limits : LogLimits
    private var instrumentationScope : InstrumentationScopeInfo
    private var includeSpanContext : Bool
    
    private var observedTimestamp : Date?
    private var body : String?
    private var severity: Severity?
    private var attributes = [String:AttributeValue]()
    private var spanContext : SpanContext?
    
    
    
    init(sharedState: LoggerSharedState, instrumentationScope: InstrumentationScopeInfo, includeSpanContext: Bool) {
        self.sharedState = sharedState
        limits = sharedState.logLimits
        self.includeSpanContext = includeSpanContext
        self.instrumentationScope = instrumentationScope
    }
    
    public func setObservedTimestamp(_ observed: Date) -> Self {
        self.observedTimestamp = observed
        return self
    }
    
    public func setSpanContext(_ context: OpenTelemetryApi.SpanContext) -> Self {
        self.spanContext = spanContext

        return self
    }
    
    public func setSeverity(_ severity: OpenTelemetryApi.Severity) -> Self {
        self.severity = severity
        return self
    }
    
    public func setBody(_ body: String) -> Self {
        self.body = body
        return self
    }
    
    public func setAttributes(_ attributes: [String : OpenTelemetryApi.AttributeValue]) -> Self {
        self.attributes = attributes
        return self
    }
    
    
    public func emit() {
        
        
        if spanContext == nil && includeSpanContext {
            spanContext = OpenTelemetry.instance.contextProvider.activeSpan?.context
        }
        
        sharedState.activeLogRecordProcessor.onEmit(logRecord: ReadableLogRecord(resource: sharedState.resource,
                                                                                 instrumentationScopeInfo: instrumentationScope,
                                                                                 timestamp: sharedState.clock.now,
                                                                                 observedTimestamp: observedTimestamp,
                                                                                 spanContext: spanContext,
                                                                                 severity: severity,
                                                                                 body: body,
                                                                                 attributes: attributes))
    }
    
    
}
