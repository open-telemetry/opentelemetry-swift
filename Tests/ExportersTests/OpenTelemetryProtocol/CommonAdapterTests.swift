// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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
