/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import XCTest

class ResourceAdapterTests: XCTestCase {
  func testToResource() {
    let resource = Resource(attributes: ["key_bool": AttributeValue.bool(true),
                                         "key_string": AttributeValue.string("string"),
                                         "key_int": AttributeValue.int(100),
                                         "key_double": AttributeValue.double(100.3)])

    let protoResource = ResourceAdapter.toProtoResource(resource: resource)

    XCTAssertEqual(protoResource.attributes.count, 4)

    var boolAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
    boolAttribute.key = "key_bool"
    boolAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
    boolAttribute.value.boolValue = true
    XCTAssertNotNil(protoResource.attributes.first { $0 == boolAttribute })

    var stringAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
    stringAttribute.key = "key_string"
    stringAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
    stringAttribute.value.stringValue = "string"
    XCTAssertNotNil(protoResource.attributes.first { $0 == stringAttribute })

    var intAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
    intAttribute.key = "key_int"
    intAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
    intAttribute.value.intValue = 100
    XCTAssertNotNil(protoResource.attributes.first { $0 == intAttribute })

    var doubleAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
    doubleAttribute.key = "key_double"
    doubleAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
    doubleAttribute.value.doubleValue = 100.3
    XCTAssertNotNil(protoResource.attributes.first { $0 == doubleAttribute })
  }
}
