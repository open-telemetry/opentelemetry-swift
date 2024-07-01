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
    case let .set(value):
      keyValue.value.kvlistValue.values = value.labels.map({
        return toProtoAttribute(key: $0, attributeValue: $1)
      })
    case let .array(value):
      keyValue.value.arrayValue.values = value.values.map({
        return toProtoAnyValue(attributeValue: $0)
      })
    case let .stringArray(value):
      keyValue.value.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .string($0))
      })
    case let .boolArray(value):
      keyValue.value.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .bool($0))
      })
    case let .intArray(value):
      keyValue.value.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .int($0))
      })
    case let .doubleArray(value):
      keyValue.value.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .double($0))
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
    case let .set(value):
      anyValue.kvlistValue.values = value.labels.map({
        return toProtoAttribute(key: $0, attributeValue: $1)
      })
    case let .array(value):
      anyValue.arrayValue.values = value.values.map({
        return toProtoAnyValue(attributeValue: $0)
      })
    case let .stringArray(value):
      anyValue.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .string($0))
      })
    case let .boolArray(value):
      anyValue.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .bool($0))
      })
    case let .intArray(value):
      anyValue.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .int($0))
      })
    case let .doubleArray(value):
      anyValue.arrayValue.values = value.map({
        return toProtoAnyValue(attributeValue: .double($0))
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
