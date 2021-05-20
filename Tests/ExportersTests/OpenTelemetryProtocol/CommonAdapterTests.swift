/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporter
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

    func testToProtoInstrumentationLibrary() {
        let instrumentationLibrary = CommonAdapter.toProtoInstrumentationLibrary(instrumentationLibraryInfo: InstrumentationLibraryInfo(name: "name", version: "version"))
        XCTAssertEqual(instrumentationLibrary.name, "name")
        XCTAssertEqual(instrumentationLibrary.version, "version")
    }

    func testToProtoInstrumentationLibraryNoVersion() {
        let instrumentationLibrary = CommonAdapter.toProtoInstrumentationLibrary(instrumentationLibraryInfo: InstrumentationLibraryInfo(name: "name"))
        XCTAssertEqual(instrumentationLibrary.name, "name")
        XCTAssertEqual(instrumentationLibrary.version, "")
    }
}
