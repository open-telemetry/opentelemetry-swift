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
        XCTAssertNotNil(protoResource.attributes.first{ $0 == boolAttribute })
        
        var stringAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
        stringAttribute.key = "key_string"
        stringAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        stringAttribute.value.stringValue = "string"
        XCTAssertNotNil(protoResource.attributes.first{ $0 == stringAttribute  })
        
        var intAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
        intAttribute.key = "key_int"
        intAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        intAttribute.value.intValue = 100
        XCTAssertNotNil(protoResource.attributes.first{ $0 == intAttribute })
        
        var doubleAttribute = Opentelemetry_Proto_Common_V1_KeyValue()
        doubleAttribute.key = "key_double"
        doubleAttribute.value = Opentelemetry_Proto_Common_V1_AnyValue()
        doubleAttribute.value.doubleValue = 100.3
        XCTAssertNotNil(protoResource.attributes.first{ $0 == doubleAttribute })
        
    }
}
