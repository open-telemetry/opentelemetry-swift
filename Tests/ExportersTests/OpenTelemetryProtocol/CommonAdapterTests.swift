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
}
