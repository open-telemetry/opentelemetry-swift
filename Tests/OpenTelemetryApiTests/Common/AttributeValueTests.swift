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
import XCTest

class AttributeValueTest: XCTestCase {
    func testAttributeValue_EqualsAndHashCode() {
        XCTAssertEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeDiffValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.boolArray([true, true]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.bool(true), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.bool(false))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.boolArray([true, true]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.int(123456), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.int(1234567))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.boolArray([true, true]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.double(1.23456), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.double(1.234567))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.boolArray([true, true]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue.stringArray(["MyStringAttributeValue2", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue.boolArray([true, true]))
        XCTAssertNotEqual(AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.stringArray(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.boolArray([true, true]), AttributeValue.boolArray([true, true]))

        XCTAssertNotEqual(AttributeValue.boolArray([true, true]), AttributeValue.boolArray([true, false]))
        XCTAssertNotEqual(AttributeValue.boolArray([true, true]), AttributeValue.intArray([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.boolArray([true, true]), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.intArray([123456, 123456]), AttributeValue.intArray([123456, 123456]))

        XCTAssertNotEqual(AttributeValue.intArray([123456, 123456]), AttributeValue.intArray([123457, 123456]))
        XCTAssertNotEqual(AttributeValue.intArray([123456, 123456]), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.doubleArray([1.23456, 1.23456]), AttributeValue.doubleArray([1.23456, 1.23456]))
        XCTAssertNotEqual(AttributeValue.doubleArray([1.23456, 1.23456]), AttributeValue.doubleArray([1.23456, 2.23456]))
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
        attribute = AttributeValue.stringArray(["MyStringAttributeValue1", "MyStringAttributeValue2"])
        XCTAssert(attribute.description.contains("MyStringAttributeValue1"))
        XCTAssert(attribute.description.contains("MyStringAttributeValue2"))
        attribute = AttributeValue.boolArray([true, false])
        XCTAssertEqual(attribute.description, "[true, false]")
        attribute = AttributeValue.intArray([1, 3, 2])
        XCTAssertEqual(attribute.description, "[1, 3, 2]")
        attribute = AttributeValue.doubleArray([1.11, 0.01, -2.22])
        XCTAssertEqual(attribute.description, "[1.11, 0.01, -2.22]")
    }
}
