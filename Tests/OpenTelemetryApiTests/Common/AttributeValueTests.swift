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

@testable import OpenTelemetryApi
import XCTest

class AttributeValueTest: XCTestCase {
    func testAttributeValue_EqualsAndHashCode() {
        XCTAssertEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeDiffValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.double(1.23456))
        XCTAssertEqual(AttributeValue.bool(true), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.bool(false))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.double(1.23456))
        XCTAssertEqual(AttributeValue.int(123456), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.int(1234567))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.double(1.23456))
        XCTAssertEqual(AttributeValue.double(1.23456), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.double(1.234567))
    }

    func testAttributeValue_Tostring() {
        var attribute = AttributeValue.string("MyStringAttributeValue")
        XCTAssert(attribute.description.contains("MyStringAttributeValue"))
        attribute = AttributeValue.bool(true)
        XCTAssert(attribute.description.contains("true"))
        attribute = AttributeValue.int(123456)
        XCTAssert(attribute.description.contains("123456"))
        attribute = AttributeValue.double(1.23456)
        XCTAssert(attribute.description.contains("1.23456"))
    }
}
