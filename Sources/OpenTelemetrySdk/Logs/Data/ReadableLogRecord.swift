/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public struct ReadableLogRecord : Codable {
    public init(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, timestamp: Date, observedTimestamp: Date? = nil, spanContext: SpanContext? = nil, severity: Severity? = nil, body: AttributeValue? = nil, attributes: [String : AttributeValue]) {
        self.resource = resource
        self.instrumentationScopeInfo = instrumentationScopeInfo
        self.timestamp = timestamp
        self.observedTimestamp = observedTimestamp
        self.spanContext = spanContext
        self.severity = severity
        self.body = body
        self.attributes = attributes
    }
        
    public private(set) var resource : Resource
    public private(set) var instrumentationScopeInfo : InstrumentationScopeInfo
    public private(set) var timestamp : Date
    public private(set) var observedTimestamp :  Date?
    public private(set) var spanContext : SpanContext?
    public private(set) var severity : Severity?
    public private(set) var body: AttributeValue?
    public private(set) var attributes : [String: AttributeValue]
}


