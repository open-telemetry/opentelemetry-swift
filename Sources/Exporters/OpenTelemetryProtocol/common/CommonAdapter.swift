/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct CommonAdapter {
    static func toProtoAttribute(key: String, attributeValue: AttributeValue) -> Opentelemetry_Proto_Common_V1_KeyValue {
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
        }
        return keyValue
    }
    
    static func toProtoInstrumentationLibrary(instrumentationLibraryInfo: InstrumentationLibraryInfo) -> Opentelemetry_Proto_Common_V1_InstrumentationLibrary {
        
        var instrumentationLibrary = Opentelemetry_Proto_Common_V1_InstrumentationLibrary()
        instrumentationLibrary.name = instrumentationLibraryInfo.name
        if let version = instrumentationLibraryInfo.version {
            instrumentationLibrary.version = version
        }
        return instrumentationLibrary
    }

}
