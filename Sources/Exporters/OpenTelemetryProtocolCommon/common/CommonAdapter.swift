/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct CommonAdapter {
  public static func toProtoAttribute(key: String, attributeValue: AttributeValue)
  -> Opentelemetry_Proto_Common_V1_KeyValue
  {
    var keyValue = Opentelemetry_Proto_Common_V1_KeyValue()
    keyValue.key = key
    switch attributeValue {
    case let .string(value):
      keyValue.value.stringValue = value
    case let .bool(value):
      keyValue.value.boolValue = value
    case let .int(value):
      keyValue.value.intValue = Int64(value)
    case let .double(value):
      keyValue.value.doubleValue = value
    case let .stringArray(value):
      keyValue.value.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.stringValue = $0
        return anyValue
      }
    case let .boolArray(value):
      keyValue.value.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.boolValue = $0
        return anyValue
      }
    case let .intArray(value):
      keyValue.value.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.intValue = Int64($0)
        return anyValue
      }
    case let .doubleArray(value):
      keyValue.value.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.doubleValue = $0
        return anyValue
      }
    case let .set(value):
      keyValue.value.kvlistValue.values = value.labels.map({
        return toProtoAttribute(key: $0, attributeValue: $1)
      })
    }
    return keyValue
  }
  
  public static func toProtoAnyValue(attributeValue: AttributeValue) -> Opentelemetry_Proto_Common_V1_AnyValue {
    var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
    switch attributeValue {
    case let .string(value):
      anyValue.stringValue = value
    case let .bool(value):
      anyValue.boolValue = value
    case let .int(value):
      anyValue.intValue = Int64(value)
    case let .double(value):
      anyValue.doubleValue = value
    case let .stringArray(value):
      anyValue.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.stringValue = $0
        return anyValue
      }
    case let .boolArray(value):
      anyValue.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.boolValue = $0
        return anyValue
      }
    case let .intArray(value):
      anyValue.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.intValue = Int64($0)
        return anyValue
      }
    case let .doubleArray(value):
      anyValue.arrayValue.values = value.map {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        anyValue.doubleValue = $0
        return anyValue
      }
    case let .set(value):
      anyValue.kvlistValue.values = value.labels.map({
        return toProtoAttribute(key: $0, attributeValue: $1)
      })
    }
    return anyValue
  }
  
  public static func toProtoInstrumentationScope(instrumentationScopeInfo: InstrumentationScopeInfo)
  -> Opentelemetry_Proto_Common_V1_InstrumentationScope
  {
    
    var instrumentationScope = Opentelemetry_Proto_Common_V1_InstrumentationScope()
    instrumentationScope.name = instrumentationScopeInfo.name
    if let version = instrumentationScopeInfo.version {
      instrumentationScope.version = version
    }
    return instrumentationScope
  }
  
}
