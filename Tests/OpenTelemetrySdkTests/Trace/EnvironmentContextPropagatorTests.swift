/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

// Minimal Setter/Getter that store/retrieve values as-is, letting
// EnvironmentMappingSetter / EnvironmentMappingGetter own all key transformation.
private struct CapturingSetter: Setter {
  func set(carrier: inout [String: String], key: String, value: String) {
    carrier[key] = value
  }
}

private struct CapturingGetter: Getter {
  func get(carrier: [String: String], key: String) -> [String]? {
    carrier[key].map { [$0] }
  }
}

class EnvironmentContextPropagatorTests: XCTestCase {
  private let setter = EnvironmentMappingSetter(innerSetter: CapturingSetter())
  private let getter = EnvironmentMappingGetter(innerGetter: CapturingGetter())

  // MARK: - EnvironmentMappingSetter key normalization

  func testLowercaseLettersAreUppercased() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "traceparent", value: "v")
    XCTAssertEqual(carrier, ["TRACEPARENT": "v"])
  }

  func testUppercaseLettersArePreserved() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "TRACEPARENT", value: "v")
    XCTAssertEqual(carrier, ["TRACEPARENT": "v"])
  }

  func testMixedCaseIsUppercased() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "traceParent", value: "v")
    XCTAssertEqual(carrier, ["TRACEPARENT": "v"])
  }

  func testHyphenIsReplacedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "x-b3-traceid", value: "v")
    XCTAssertEqual(carrier, ["X_B3_TRACEID": "v"])
  }

  func testUnderscoreIsPreserved() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "trace_id", value: "v")
    XCTAssertEqual(carrier, ["TRACE_ID": "v"])
  }

  func testDigitInMiddleIsPreserved() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "b3-123", value: "v")
    XCTAssertEqual(carrier, ["B3_123": "v"])
  }

  func testLeadingDigitIsPrefixedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "3foo", value: "v")
    XCTAssertEqual(carrier, ["_3FOO": "v"])
  }

  func testLeadingDigitZeroIsPrefixedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "0abc", value: "v")
    XCTAssertEqual(carrier, ["_0ABC": "v"])
  }

  func testAllDigitsArePrefixedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "123", value: "v")
    XCTAssertEqual(carrier, ["_123": "v"])
  }

  func testSpecialCharactersAreReplacedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "a.b:c/d", value: "v")
    XCTAssertEqual(carrier, ["A_B_C_D": "v"])
  }

  func testNonAsciiLettersAreReplacedWithUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "héllo", value: "v")
    XCTAssertEqual(carrier, ["H_LLO": "v"])

    carrier.removeAll()
    setter.set(carrier: &carrier, key: "über", value: "v")
    XCTAssertEqual(carrier, ["_BER": "v"])
  }

  func testNonAsciiDigitsAreReplacedWithUnderscore() {
    // ２ is a full-width digit (U+FF12); should become _
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "２foo", value: "v")
    XCTAssertEqual(carrier, ["_FOO": "v"])
  }

  func testEmptyStringNormalizesToUnderscore() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "", value: "v")
    XCTAssertEqual(carrier, ["_": "v"])
  }

  func testOnlySpecialCharacters() {
    var carrier = [String: String]()
    setter.set(carrier: &carrier, key: "---", value: "v")
    XCTAssertEqual(carrier, ["___": "v"])
  }

  // MARK: - EnvironmentMappingGetter key normalization

  func testGetterNormalizesLookupKey() {
    let carrier = ["TRACEPARENT": "value"]
    XCTAssertEqual(getter.get(carrier: carrier, key: "traceparent"), ["value"])
  }

  func testGetterIgnoresNonNormalizedCarrierKeys() {
    // Carrier stored with a non-normalized key; getter must NOT fall back to normalizing
    // carrier keys, only the requested key is normalized.
    let carrier = ["traceparent": "value"]
    XCTAssertNil(getter.get(carrier: carrier, key: "traceparent"))
  }

  func testGetterReturnsNilForMissingKey() {
    let carrier = ["TRACEPARENT": "value"]
    XCTAssertNil(getter.get(carrier: carrier, key: "tracestate"))
  }

  func testGetterEmptyKeyNormalizesToUnderscore() {
    let carrier = ["_": "value"]
    XCTAssertEqual(getter.get(carrier: carrier, key: ""), ["value"])
  }
}
