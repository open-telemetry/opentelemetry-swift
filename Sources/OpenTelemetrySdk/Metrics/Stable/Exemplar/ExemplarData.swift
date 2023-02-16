//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol ExemplarData {
    func getFilteredAttributes() -> [String: AttributeValue]
    func getEpochNanos() -> UInt64
    func getSpanContext() -> SpanContext?
}


public protocol DoubleExemplarData : ExemplarData {
    func getValue() -> Double
}

public protocol LongExemplarData : ExemplarData {
    func getValue() -> Int
}

public struct ImmutableDoubleExemplarData : DoubleExemplarData {
    let filteredAttributes:  [String: AttributeValue]
    let recordTimeNanos : UInt64
    let spanContext: SpanContext?
    let value : Double
    
    public func getFilteredAttributes() -> [String : OpenTelemetryApi.AttributeValue] {
        filteredAttributes
    }
    
    public func getEpochNanos() -> UInt64 {
        recordTimeNanos
    }
    
    public func getSpanContext() -> OpenTelemetryApi.SpanContext? {
        spanContext
    }
    
    public func getValue() -> Double {
        value
    }
}

public struct ImmutableLongExemplarData : LongExemplarData {
  
    let filteredAttributes:  [String: AttributeValue]
    let recordTimeNanos : UInt64
    let spanContext: SpanContext?
    let value : Int
    
    public func getValue() -> Int {
        value
    }
    
    public func getFilteredAttributes() -> [String : OpenTelemetryApi.AttributeValue] {
        filteredAttributes
    }
    
    public func getEpochNanos() -> UInt64 {
        recordTimeNanos
    }
    
    public func getSpanContext() -> OpenTelemetryApi.SpanContext? {
        spanContext
    }
    
    
}
