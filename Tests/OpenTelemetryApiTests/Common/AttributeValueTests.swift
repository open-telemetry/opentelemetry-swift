/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class AttributeValueTest: XCTestCase {
    func testAttributeValue_EqualsAndHashCode() {
        XCTAssertEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.string("MyStringAttributeDiffValue"))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue.int(123456))
      XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue([true, true]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.string("MyStringAttributeValue"), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.bool(true), AttributeValue.bool(true))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.bool(false))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue([true, true]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.bool(true), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.int(123456), AttributeValue.int(123456))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.int(1234567))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue([true, true]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.int(123456), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue.double(1.23456), AttributeValue.double(1.23456))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue.double(1.234567))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue([true, true]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue.double(1.23456), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue(["MyStringAttributeValue2", "MyStringAttributeValue"]))
        XCTAssertNotEqual(AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue([true, true]))
        XCTAssertNotEqual(AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue(["MyStringAttributeValue", "MyStringAttributeValue"]), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue([true, true]), AttributeValue([true, true]))

        XCTAssertNotEqual(AttributeValue([true, true]), AttributeValue([true, false]))
        XCTAssertNotEqual(AttributeValue([true, true]), AttributeValue([123456, 123456]))
        XCTAssertNotEqual(AttributeValue([true, true]), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue([123456, 123456]), AttributeValue([123456, 123456]))

        XCTAssertNotEqual(AttributeValue([123456, 123456]), AttributeValue([123457, 123456]))
        XCTAssertNotEqual(AttributeValue([123456, 123456]), AttributeValue([1.23456, 1.23456]))
        XCTAssertEqual(AttributeValue([1.23456, 1.23456]), AttributeValue([1.23456, 1.23456]))
        XCTAssertNotEqual(AttributeValue([1.23456, 1.23456]), AttributeValue([1.23456, 2.23456]))
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
        attribute = AttributeValue(["MyStringAttributeValue1", "MyStringAttributeValue2"])
        XCTAssert(attribute.description.contains("MyStringAttributeValue1"))
        XCTAssert(attribute.description.contains("MyStringAttributeValue2"))
        attribute = AttributeValue([true, false])
        XCTAssertEqual(attribute.description, "[true, false]")
        attribute = AttributeValue([1, 3, 2])
        XCTAssertEqual(attribute.description, "[1, 3, 2]")
        attribute = AttributeValue([1.11, 0.01, -2.22])
        XCTAssertEqual(attribute.description, "[1.11, 0.01, -2.22]")
    }
    
    func testAttributeValue_Codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var attribute = AttributeValue.string("")
        var decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.string("MyStringAttributeValue")
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.bool(true)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.int(123456)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.int(0)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.int(-123456)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.double(1.23456)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.double(0.0)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue.double(-1.23456)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
      attribute = AttributeValue.array(AttributeArray.empty)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue(["MyStringAttributeValue1", "MyStringAttributeValue2"])
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
      attribute = AttributeValue.array(AttributeArray.empty)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue([true, false])
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
      attribute = AttributeValue.array(AttributeArray.empty)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue([1, 3, 2])
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
      attribute = AttributeValue.array(AttributeArray.empty)
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        attribute = AttributeValue([1.11, 0.01, -2.22])
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute, decodedAttribute)
        
        XCTAssertThrowsError(try decoder.decode(AttributeValue.self, from: "".data(using: .utf8)!))
        XCTAssertThrowsError(try decoder.decode(AttributeValue.self,
                                                from: #"{"string":{"_0":"MyStringAttributeValue"}, "int":{"_0":1234}}"#.data(using: .utf8)!))
    }
    
    #if swift(>=5.5)
    // this test covers forward compatibility of the pre swift 5.5 encoding with post swift 5.5 decoding
    func testAttributeValue_ExplicitCodableForwardCompatibility() throws {
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.string(""))
        var decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)
        
        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.string("MyStringAttributeValue"))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.bool(true))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.int(123456))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.int(0))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.int(-123456))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.double(1.23456))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.double(0.0))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.double(-1.23456))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

      attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.array(AttributeArray.empty))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue(["MyStringAttributeValue1", "MyStringAttributeValue2"]))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.array(AttributeArray.empty))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue([true, false]))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.array(AttributeArray.empty))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue([1, 3, 2]))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue.array(AttributeArray.empty))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        attribute = AttributeValueExplicitCodable(attributeValue: AttributeValue([1.11, 0.01, -2.22]))
        decodedAttribute = try decoder.decode(AttributeValue.self, from: try encoder.encode(attribute))
        XCTAssertEqual(attribute.attributeValue, decodedAttribute)

        XCTAssertThrowsError(try decoder.decode(AttributeValueExplicitCodable.self, from: "".data(using: .utf8)!))
        XCTAssertThrowsError(try decoder.decode(AttributeValueExplicitCodable.self,
                                                from: #"{"string":{"_0":"MyStringAttributeValue"}, "int":{"_0":1234}}"#.data(using: .utf8)!))
    }
    #endif
}
