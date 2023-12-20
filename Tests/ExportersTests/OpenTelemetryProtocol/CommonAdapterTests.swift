/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import XCTest

class CommonAdapterTests: XCTestCase {
    func testToProtoAttributeBool() {
        var attribute = Opentelemetry_Proto_Common_V1_KeyValue()
        attribute.key = "key"
        attribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        attribute.value.boolValue = true
        XCTAssertEqual(CommonAdapter.toProtoAttribute(key: "key", attributeValue: AttributeValue.bool(true)), attribute)
    }

    func testToProtoAttributeString() {
        var attribute = Opentelemetry_Proto_Common_V1_KeyValue()
        attribute.key = "key"
        attribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        attribute.value.stringValue = "string"
        XCTAssertEqual(CommonAdapter.toProtoAttribute(key: "key", attributeValue: AttributeValue.string("string")), attribute)
    }

    func testToProtoAttributeInt() {
        var attribute = Opentelemetry_Proto_Common_V1_KeyValue()
        attribute.key = "key"
        attribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        attribute.value.intValue = 100
        XCTAssertEqual(CommonAdapter.toProtoAttribute(key: "key", attributeValue: AttributeValue.int(100)), attribute)
    }

    func testToProtoAttributeDouble() {
        var attribute = Opentelemetry_Proto_Common_V1_KeyValue()
        attribute.key = "key"
        attribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        attribute.value.doubleValue = 100.3
        XCTAssertEqual(CommonAdapter.toProtoAttribute(key: "key", attributeValue: AttributeValue.double(100.3)), attribute)
    }

    func testToProtoInstrumentationScope() {
        let instrumentationScope = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: InstrumentationScopeInfo(name: "name", version: "version"))
        XCTAssertEqual(instrumentationScope.name, "name")
        XCTAssertEqual(instrumentationScope.version, "version")
    }

    func testToProtoInstrumentationScopeNoVersion() {
        let instrumentationScope = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: InstrumentationScopeInfo(name: "name"))
        XCTAssertEqual(instrumentationScope.name, "name")
        XCTAssertEqual(instrumentationScope.version, "")
    }
  
  func testToProtoAnyValue() {
    
    let anyStringValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.string("hello,world"))
    XCTAssertEqual(anyStringValue.stringValue, "hello,world")
    
    let anyBoolValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.bool(false))
    XCTAssertFalse(anyBoolValue.boolValue)
    
    let anyIntValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.int(12))
    XCTAssertEqual(anyIntValue.intValue, 12)
    
    let anyDoubleValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.double(3.14))
    XCTAssertEqual(anyDoubleValue.doubleValue, 3.14)
  
    let anyStringArrayValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.stringArray(["hello"]))
    
    XCTAssertEqual(anyStringArrayValue.arrayValue.values.count, 1)
    XCTAssertTrue(anyStringArrayValue.arrayValue.values[0].stringValue == "hello")
   
    let anyBoolArrayValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.boolArray([true]))
    
    XCTAssertEqual(anyBoolArrayValue.arrayValue.values.count, 1)
    XCTAssertTrue(anyBoolArrayValue.arrayValue.values[0].boolValue)
    
    let anyIntArrayValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.intArray([1]))
    XCTAssertEqual(anyIntArrayValue.arrayValue.values.count, 1)
    XCTAssertTrue(anyIntArrayValue.arrayValue.values[0].intValue == 1)
    
    let anyDoubleArrayValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.doubleArray([3.14]))
    XCTAssertEqual(anyDoubleArrayValue.arrayValue.values.count, 1)
    XCTAssertTrue(anyDoubleArrayValue.arrayValue.values[0].doubleValue == 3.14)
    
    let anySetValue = CommonAdapter.toProtoAnyValue(attributeValue: AttributeValue.set(AttributeSet(labels: ["Hello": AttributeValue.string("world")])))
    XCTAssertTrue(anySetValue.kvlistValue.values.count == 1)
    XCTAssertTrue(anySetValue.kvlistValue.values[0].key == "Hello")
    XCTAssertTrue(anySetValue.kvlistValue.values[0].value.stringValue == "world")

    
    

    
  }
}
