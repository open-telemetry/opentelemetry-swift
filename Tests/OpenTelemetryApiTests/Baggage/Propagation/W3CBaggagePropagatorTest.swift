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

  // MARK: - Limits (https://www.w3.org/TR/baggage/#limits)

  // A 400-byte list-member. Keys and values are capped at 255, so the length goes into the properties.
  private func longListMember(_ index: Int) -> String {
    return String(format: "k%02d=v;", index) + String(repeating: "m", count: 394)
  }

  func testW3CMaxListMembers() {
    let header = (0 ..< 65).map { "k\($0)=v" }.joined(separator: ",")

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 64)
    XCTAssertNotNil(result.getEntryValue(key: EntryKey(name: "k63")!))
    XCTAssertNil(result.getEntryValue(key: EntryKey(name: "k64")!))
  }

  func testW3CExactlyMaxListMembers() {
    let header = (0 ..< 64).map { "k\($0)=v" }.joined(separator: ",")

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 64)
  }

  func testW3CInvalidListMembersDoNotCount() {
    // 64 invalid members followed by a valid one: the valid one is still accepted.
    let header = Array(repeating: "=", count: 64).joined(separator: ",") + ",k=v"

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 1)
    XCTAssertNotNil(result.getEntryValue(key: EntryKey(name: "k")!))
  }

  func testW3CHeaderOverMaxBytes() {
    // 30 members of 400 bytes. The last separator inside the first 8193 bytes follows the 20th member.
    let header = (0 ..< 30).map(longListMember).joined(separator: ",")
    XCTAssertEqual(header.utf8.count, 30 * 400 + 29)

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 20)
    XCTAssertNotNil(result.getEntryValue(key: EntryKey(name: "k19")!))
    XCTAssertNil(result.getEntryValue(key: EntryKey(name: "k20")!))
  }

  func testW3CHeaderAtMaxBytes() {
    var members = (0 ..< 20).map(longListMember) // 20 * 400 + 19 separators = 8019 bytes
    members.append("k20=v;" + String(repeating: "m", count: 166)) // + 1 separator + 172 = 8192
    let header = members.joined(separator: ",")
    XCTAssertEqual(header.utf8.count, 8192)

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 21)
  }

  func testW3CPartialListMemberDropped() {
    // The second member straddles the 8192-byte limit and is dropped whole.
    let members = ["k0=v;" + String(repeating: "m", count: 8000),
                   "k1=v;" + String(repeating: "m", count: 500)]

    let result = propagator.extract(carrier: ["baggage": members.joined(separator: ",")], getter: getter)!

    XCTAssertEqual(result.getEntries().count, 1)
    XCTAssertNotNil(result.getEntryValue(key: EntryKey(name: "k0")!))
    XCTAssertNil(result.getEntryValue(key: EntryKey(name: "k1")!))
  }

  func testW3CInjectStopsAtMaxListMembers() {
    var carrier = [String: String]()
    for index in 0 ..< 65 {
      builder.put(key: String(format: "k%02d", index), value: "v")
    }

    propagator.inject(baggage: builder.setNoParent().build(), carrier: &carrier, setter: setter)

    let members = (carrier["baggage"] ?? "").split(separator: ",").map(String.init)
    XCTAssertEqual(members.count, 64)
    // Entries are sorted before the limit applies, so the same 64 are kept on every run.
    XCTAssertEqual(members, (0 ..< 64).map { String(format: "k%02d=v", $0) })
  }

  func testW3CInjectStaysWithinMaxBytes() {
    // Values are capped at 255 characters, so each member is 259 bytes and n of them cost
    // 260n - 1. Thirty-one fit (8059); a thirty-second would be 8319.
    var carrier = [String: String]()
    for index in 0 ..< 40 {
      builder.put(key: String(format: "k%02d", index), value: String(repeating: "v", count: 255))
    }

    propagator.inject(baggage: builder.setNoParent().build(), carrier: &carrier, setter: setter)

    let header = carrier["baggage"] ?? ""
    XCTAssertLessThanOrEqual(header.utf8.count, 8192)
    XCTAssertEqual(header.split(separator: ",").count, 31)
  }

  func testW3CInjectCountsHeaderBytesNotCharacters() {
    // Metadata is written through as-is, so a multibyte one is 3 bytes per character.
    // 3000 characters are 9004 bytes with "k=v;" - over the limit - but only 3004 characters.
    var carrier = [String: String]()
    builder.put(key: "a", value: "b")
    builder.put(key: "k", value: "v", metadata: String(repeating: "\u{20AC}", count: 3000))

    propagator.inject(baggage: builder.setNoParent().build(), carrier: &carrier, setter: setter)

    XCTAssertEqual(carrier["baggage"], "a=b")
  }

  func testW3CNoListMemberFits() {
    let header = "k=v;" + String(repeating: "m", count: 9000)

    let result = propagator.extract(carrier: ["baggage": header], getter: getter)

    XCTAssertEqual(result?.getEntries().count ?? 0, 0)
  }
}
