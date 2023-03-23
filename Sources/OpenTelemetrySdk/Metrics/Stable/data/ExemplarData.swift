//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol ExemplarData {
    var epochNanos : UInt64 {get}
    var filteredAttributes: [String: AttributeValue] {get}
    var spanContext : SpanContext? {get}
}

public class AnyExemplarData : ExemplarData {
    internal init(epochNanos: UInt64, filteredAttributes: [String : AttributeValue], spanContext: SpanContext? = nil) {
        self.filteredAttributes = filteredAttributes
        self.epochNanos = epochNanos
        self.spanContext = spanContext
    }
    
    public var filteredAttributes: [String : OpenTelemetryApi.AttributeValue]
    
    public var epochNanos: UInt64
    
    public var spanContext: OpenTelemetryApi.SpanContext?
}

public protocol DoubleExemplarData : AnyExemplarData {
    var value : Double {get}
}

public protocol LongExemplarData : AnyExemplarData {
    var value : Int {get}
}


public class AnyDoubleExemplarData : AnyExemplarData, DoubleExemplarData {
    public var value: Double

    internal init(value: Double, epochNanos: UInt64, filteredAttributes: [String:AttributeValue], spanContext: SpanContext? = nil) {
        self.value = value
        super.init(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext:spanContext)
    }
}

public class ImmutableDoubleExemplarData : AnyExemplarData, DoubleExemplarData {
    public var value : Double
    internal init(filteredAttributes: [String : AttributeValue], recordTimeNanos: UInt64, spanContext: SpanContext? = nil, value: Double) {
        self.value = value
        super.init(epochNanos: recordTimeNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)

    }
}

public class ImmutableLongExemplarData : AnyExemplarData, LongExemplarData {
    public var value : Int
    internal init(filteredAttributes: [String : AttributeValue], recordTimeNanos: UInt64, spanContext: SpanContext? = nil, value: Int) {
        self.value = value
        super.init(epochNanos: recordTimeNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)

    }
}
