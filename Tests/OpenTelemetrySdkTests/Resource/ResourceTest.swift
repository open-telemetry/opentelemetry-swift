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

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class ResourceTest: XCTestCase {
    var defaultResource = Resource(attributes: [String: AttributeValue]())
    var resource1: Resource!
    var resource2: Resource!

    override func setUp() {
        let labelMap1 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
        let labelMap2 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
        resource1 = Resource(attributes: labelMap1)
        resource2 = Resource(attributes: labelMap2)
    }

    func testCreate() {
        let labelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
        let resource = Resource(attributes: labelMap)
        XCTAssertEqual(resource.attributes.count, 2)
        XCTAssertEqual(resource.attributes, labelMap)
        let resource1 = Resource(attributes: [String: AttributeValue]())
        XCTAssertEqual(resource1.attributes.count, 0)
    }

    func testResourceEquals() {
        let labelMap1 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
        let labelMap2 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
        XCTAssertEqual(Resource(attributes: labelMap1), Resource(attributes: labelMap1))
        XCTAssertNotEqual(Resource(attributes: labelMap1), Resource(attributes: labelMap2))
    }

    func testMergeResources() {
        let expectedLabelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
        let resource = defaultResource.merging(other: resource1).merging(other: resource2)
        XCTAssertEqual(resource.attributes, expectedLabelMap)
    }

    func testMergeResources_Resource1() {
        let expectedLabelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
        let resource = defaultResource.merging(other: resource1)
        XCTAssertEqual(resource.attributes, expectedLabelMap)
    }
}
