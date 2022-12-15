/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public struct ReadableLogRecord {
    public private(set) var resource : Resource
    public private(set) var instrumentationScopeInfo : InstrumentationScopeInfo
    public private(set) var timestamp : Date
    public private(set) var observedTimestamp :  Date?
    public private(set) var spanContext : SpanContext?
    public private(set) var severity : Severity?
    public private(set) var body: String?
    public private(set) var attributes : [String: AttributeValue]
}
