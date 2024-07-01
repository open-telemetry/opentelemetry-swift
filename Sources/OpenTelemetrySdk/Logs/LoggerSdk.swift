//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class LoggerSdk : OpenTelemetryApi.Logger {
    private let sharedState: LoggerSharedState
    private let instrumentationScope : InstrumentationScopeInfo
    private let eventDomain: String?
    private let withTraceContext: Bool

    init(sharedState : LoggerSharedState, instrumentationScope: InstrumentationScopeInfo, eventDomain: String?, withTraceContext: Bool = true) {
        self.sharedState = sharedState
        self.instrumentationScope = instrumentationScope
        self.eventDomain = eventDomain
        self.withTraceContext = withTraceContext
    }
    
    public func eventBuilder(name: String) -> OpenTelemetryApi.EventBuilder {
        guard let eventDomain = self.eventDomain else {
            OpenTelemetry.instance.feedbackHandler?("Events cannot be emitted from Logger without an event domain. Use `LoggerBuilder.setEventDomain(_ domain: String) when obtaining a Logger.")
            return DefaultLoggerProvider.instance.loggerBuilder(instrumentationScopeName: "unused").setEventDomain("unused").setAttributes(["event.domain": AttributeValue.string("unused"), "event.name": AttributeValue.string(name)]).build().eventBuilder(name: "unused")
        }
        return LogRecordBuilderSdk(sharedState: sharedState, instrumentationScope: instrumentationScope, includeSpanContext: true).setAttributes(["event.domain": AttributeValue.string(eventDomain),
                                                                                                                                                  "event.name": AttributeValue.string(name)])
    }
    
    public func logRecordBuilder() -> OpenTelemetryApi.LogRecordBuilder {
        return LogRecordBuilderSdk(sharedState: sharedState, instrumentationScope: instrumentationScope, includeSpanContext: true)
    }
    
    
    func withEventDomain(domain: String) -> LoggerSdk {
        if eventDomain == domain {
            return self
        } else {
            return LoggerSdk(sharedState: sharedState, instrumentationScope: instrumentationScope, eventDomain: domain, withTraceContext: withTraceContext)
        }
    }
    
    func withoutTraceContext() -> LoggerSdk {
        return LoggerSdk(sharedState: sharedState, instrumentationScope: instrumentationScope, eventDomain: self.eventDomain, withTraceContext: false)
    }
    
}
