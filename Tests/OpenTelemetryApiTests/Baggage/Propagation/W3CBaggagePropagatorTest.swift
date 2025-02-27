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

  func testFields() {
    XCTAssertEqual(propagator.fields.count, 1)
    XCTAssertTrue(propagator.fields.contains("baggage"))
  }

  func testxtractNoBaggageHeader() {
    let result = propagator.extract(carrier: [:], getter: getter)
    XCTAssertNil(result)
  }

  func testExtractEmptyBaggageHeader() {
    let result = propagator.extract(carrier: ["baggage": ""], getter: getter)
    XCTAssertEqual(result?.getEntries().count, 0)
  }

  func testExtractSingleEntry() {
    let result = propagator.extract(carrier: ["baggage": "key=value"], getter: getter)!
    let expectedBaggage = builder.put(key: "key", value: "value").build()
    XCTAssert(result == expectedBaggage)
  }

  func testExtractMultiEntry() {
    let result = propagator.extract(carrier: ["baggage": "key1=value1,key2=value2"], getter: getter)!
    let expectedBaggage = builder.put(key: "key1", value: "value1").put(key: "key2", value: "value2").build()
    XCTAssert(result == expectedBaggage)
  }

  func testExtractDuplicateKeys() {
    let result = propagator.extract(carrier: ["baggage": "key=value1,key=value2"], getter: getter)!
    let expectedBaggage = builder.put(key: "key", value: "value2").build()
    XCTAssert(result == expectedBaggage)
  }

  func testExtractWithMetadata() {
    let result = propagator.extract(carrier: ["baggage": "key=value;metadata-key=value;othermetadata"], getter: getter)!
    let expectedBaggage = builder.put(key: "key", value: "value", metadata: "metadata-key=value;othermetadata")
      .build()
    XCTAssert(result == expectedBaggage)
  }

  func testExtractFullComplexities() {
    let result = propagator.extract(carrier: ["baggage": "key1= value1; metadata-key = value; othermetadata, " +
        "key2 =value2 , key3 =\tvalue3 ; "], getter: getter)!
    let expectedBaggage = builder.put(key: "key1", value: "value1", metadata: "metadata-key = value; othermetadata")
      .put(key: "key2", value: "value2")
      .put(key: "key3", value: "value3")
      .build()
    XCTAssert(result == expectedBaggage)
  }

  func testInjectEmptyBaggage() {
    var carrier = [String: String]()
    propagator.inject(baggage: EmptyBaggage.instance, carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier.count, 0)
  }

  func testInject() {
    let baggage = builder.put(key: "nometa", value: "nometa-value")
      .put(key: "nometa", value: "nometa-value")
      .put(key: "meta", value: "meta-value", metadata: "somemetadata; someother=foo")
      .build()

    var carrier = [String: String]()
    propagator.inject(baggage: baggage, carrier: &carrier, setter: setter)

    let expected1 = ["baggage": "meta=meta-value;somemetadata; someother=foo,nometa=nometa-value"]
    let expected2 = ["baggage": "nometa=nometa-value,meta=meta-value;somemetadata; someother=foo"]
    XCTAssert(carrier == expected1 || carrier == expected2)
  }
}
