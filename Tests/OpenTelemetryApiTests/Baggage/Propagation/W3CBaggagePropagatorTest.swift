/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class W3BaggagePropagatorTest: XCTestCase {
  let setter = TestSetter()
  let getter = TestGetter()
  let propagator = W3CBaggagePropagator()
  let builder = DefaultBaggageBuilder()

  override func setUp() {}

  override func tearDown() {}

  // MARK: - W3C Specification Compliance Tests

  func testW3CFields() {
    XCTAssertEqual(propagator.fields.count, 1)
    XCTAssertTrue(propagator.fields.contains("baggage"))
  }

  func testW3CNoBaggageHeader() {
    let result = propagator.extract(carrier: [:], getter: getter)
    XCTAssertNil(result)
  }

  func testW3CEmptyBaggageHeader() {
    let carrier = [
      "baggage": ""
    ]

    let result = propagator.extract(carrier: carrier, getter: getter)
    XCTAssertEqual(result?.getEntries().count, 0)
  }

  func testW3CDuplicateKeys() {
    let carrier = [
      "baggage": "key=value1,key=value2"
    ]

    let result = propagator.extract(carrier: carrier, getter: getter)!
    let expectedBaggage = builder.put(key: "key", value: "value2").build()
    XCTAssert(result == expectedBaggage)
  }

  func testW3CInjectEmptyBaggage() {
    var carrier = [String: String]()
    propagator.inject(baggage: EmptyBaggage.instance, carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier.count, 0)
  }

  func testW3CExampleSingleHeader() {
    // Test case from W3C spec: "userId=alice,serverNode=DF%2028,isProduction=false"
    let carrier = [
      "baggage": "userId=alice,serverNode=DF%2028,isProduction=false"
    ]

    let result = propagator.extract(carrier: carrier, getter: getter)!

    let expectedBaggage = builder
      .put(key: "userId", value: "alice")
      .put(key: "serverNode", value: "DF 28")
      .put(key: "isProduction", value: "false")
      .build()

    XCTAssert(result == expectedBaggage)
  }

  func testW3CExampleWithSpecialCharacters() {
    // Test case from W3C spec: "userId=Am%C3%A9lie,serverNode=DF%2028,isProduction=false"
    let carrier = [
      "baggage": "userId=Am%C3%A9lie,serverNode=DF%2028,isProduction=false"
    ]

    let result = propagator.extract(carrier: carrier, getter: getter)!

    let expectedBaggage = builder
      .put(key: "userId", value: "Amélie")
      .put(key: "serverNode", value: "DF 28")
      .put(key: "isProduction", value: "false")
      .build()

    XCTAssert(result == expectedBaggage)
  }

  func testW3CExampleMultipleHeaders() {
    // Test case from W3C spec for multiple headers
    let carrier = [
      "baggage": "userId=alice",
      "Baggage": "serverNode=DF%2028,isProduction=false"
    ]

    let result = propagator.extract(carrier: carrier, getter: getter)!

    // According to spec, should only process the first header
    let expectedBaggage = builder
      .put(key: "userId", value: "alice")
      .build()

    XCTAssert(result == expectedBaggage)
  }

  func testW3CSpecExamples() {
    // Examples directly from the spec
    let examples = [
      "key1=value1,key2=value2",
      "key1 = value1, key2 = value2",
      "key1=value1;property=value"
    ]

    for example in examples {
      let result = propagator.extract(carrier: ["baggage": example], getter: getter)
      XCTAssertNotNil(result, "Failed to parse valid example: \(example)")
    }
  }

  func testW3CPropertyValues() {
    // Test case with properties as defined in W3C spec
    let result = propagator.extract(carrier: ["baggage": "key1=value1;property1;property2=value"], getter: getter)!

    let expectedBaggage = builder
      .put(key: "key1", value: "value1", metadata: "property1;property2=value")
      .build()

    XCTAssert(result == expectedBaggage)
  }

  func testW3CInjectionExamples() {
    var carrier = [String: String]()

    let baggage = builder
      .put(key: "userId", value: "Amélie")
      .put(key: "serverNode", value: "DF 28")
      .put(key: "isProduction", value: "false")
      .build()

    propagator.inject(baggage: baggage, carrier: &carrier, setter: setter)

    // Get the actual value for debugging
    let actualValue = carrier["baggage"] ?? ""

    // Split and sort the entries to compare content regardless of order
    let actualEntries = Set(actualValue.split(separator: ",").map(String.init))
    let expectedEntries = Set([
      "userId=Am%C3%A9lie",
      "serverNode=DF%2028",
      "isProduction=false"
    ])

    XCTAssertEqual(actualEntries, expectedEntries,
                   "Expected entries: \(expectedEntries)\nActual entries: \(actualEntries)")
  }

  func testW3CInvalidCharacters() {
    let invalidInputs = [
      // Invalid characters in key
      "key@=value", // @ not allowed in token
      "key,=value", // comma not allowed in token
      "key;=value", // semicolon not allowed in token
      "key\"=value", // quote not allowed in token

      // Empty parts
      "=value", // empty key
      "key=", // empty value
      "=", // both empty
      "", // completely empty

      // Invalid percent-encoding
      "key=%", // incomplete percent-encoding
      "key=%XY" // invalid hex digits
    ]

    for invalidInput in invalidInputs {
      let carrier = ["baggage": invalidInput]
      let baggage = propagator.extract(carrier: carrier, getter: getter)
      XCTAssertEqual(baggage?.getEntries().count ?? 0, 0,
                     "Should reject invalid input: \(invalidInput)")
    }
  }

  func testW3CValidCharacters() {
    let validInputs = [
      // Basic valid case
      "key=value",

      // Whitespace cases
      "key =value",
      "key= value",
      "key = value",
      " key=value ",

      // Valid key characters (RFC7230 token)
      "key-1=value",
      "key.2=value",
      "KEY_3=value",

      // Values with equals signs
      "key=value=more",

      // Percent-encoded values
      "key=value%20with%20spaces",
      "key=special%3Dequals",
      "key=unicode%C3%A9", // é

      // Valid baggage-octets without encoding
      "key=value-123",
      "key=!value",
      "key=value~"
    ]

    for validInput in validInputs {
      let carrier = ["baggage": validInput]
      let baggage = propagator.extract(carrier: carrier, getter: getter)
      XCTAssertEqual(baggage?.getEntries().count, 1,
                     "Should accept valid input: \(validInput)")
    }
  }
}
