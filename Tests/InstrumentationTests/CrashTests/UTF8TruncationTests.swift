/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
@testable import Crash

final class UTF8TruncationTests: XCTestCase {
  private func truncate(_ string: String, _ maxBytes: Int) -> String {
    UTF8Truncation.truncate(string, maxBytes: maxBytes)
  }

  /// Checks the contract for one input and limit: the result is a prefix made of whole characters,
  /// it fits in `maxBytes`, and it is the longest such prefix.
  private func assertTruncationContract(_ string: String,
                                        _ maxBytes: Int,
                                        file: StaticString = #filePath,
                                        line: UInt = #line) {
    let result = truncate(string, maxBytes)
    let limit = max(maxBytes, 0)
    let context = "input \(string.debugDescription), maxBytes \(maxBytes)"

    XCTAssertLessThanOrEqual(result.utf8.count, limit, "exceeds the byte limit: \(context)", file: file, line: line)
    XCTAssertTrue(Array(string).starts(with: Array(result)), "not a prefix of whole characters: \(context)", file: file, line: line)

    if result.count < string.count {
      let next = string[string.index(string.startIndex, offsetBy: result.count)]
      XCTAssertGreaterThan(result.utf8.count + String(next).utf8.count, limit,
                           "the next character also fits, so the cut is too short: \(context)", file: file, line: line)
    } else {
      XCTAssertEqual(result, string, context, file: file, line: line)
    }
  }

  // MARK: - Fits within the limit

  func testShortStringsAreUnchanged() {
    XCTAssertEqual(truncate("abc", 3), "abc")
    XCTAssertEqual(truncate("abc", 10), "abc")
  }

  func testEmptyStringStaysEmpty() {
    XCTAssertEqual(truncate("", 0), "")
    XCTAssertEqual(truncate("", 10), "")
  }

  func testExactFitIsUnchanged() {
    XCTAssertEqual(truncate("aé", 3), "aé")
    XCTAssertEqual(truncate("😀😀", 8), "😀😀")
  }

  // MARK: - Degenerate limits

  func testZeroLimitYieldsEmptyString() {
    XCTAssertEqual(truncate("abc", 0), "")
  }

  func testNegativeLimitIsTreatedAsZero() {
    XCTAssertEqual(truncate("abc", -1), "")
    XCTAssertEqual(truncate("abc", Int.min), "")
  }

  // MARK: - Multi-byte scalars

  func testASCIICutsExactlyAtTheLimit() {
    XCTAssertEqual(truncate("abcdef", 4), "abcd")
  }

  func testTwoByteScalarIsNotSplit() {
    // "é" (U+00E9) is 2 UTF-8 bytes, so a 2-byte limit lands inside it.
    XCTAssertEqual(truncate("aé", 2), "a")
  }

  func testThreeByteScalarIsNotSplit() {
    // "€" (U+20AC) is 3 UTF-8 bytes.
    XCTAssertEqual(truncate("a€", 2), "a")
    XCTAssertEqual(truncate("a€", 3), "a")
    XCTAssertEqual(truncate("a€", 4), "a€")
  }

  func testFourByteScalarIsNotSplit() {
    // Each emoji is 4 bytes; 6 bytes cuts through the second one.
    XCTAssertEqual(truncate("😀😀", 6), "😀")
    XCTAssertEqual(truncate("😀", 3), "")
  }

  // MARK: - Grapheme clusters

  func testCombiningSequenceIsKeptWhole() {
    // "e" followed by U+0301 COMBINING ACUTE ACCENT is one character of 3 bytes.
    let decomposed = "e\u{301}"
    XCTAssertEqual(decomposed.count, 1)
    XCTAssertEqual(truncate("a" + decomposed, 2), "a")
    XCTAssertEqual(truncate("a" + decomposed, 3), "a")
    XCTAssertEqual(truncate("a" + decomposed, 4), "a" + decomposed)
  }

  func testEmojiZWJSequenceIsKeptWhole() {
    let family = "👨‍👩‍👧"
    XCTAssertEqual(family.count, 1)
    XCTAssertEqual(truncate("a" + family, family.utf8.count), "a")
    XCTAssertEqual(truncate("a" + family, family.utf8.count + 1), "a" + family)
  }

  func testFlagIsKeptWhole() {
    // A flag is two 4-byte regional indicators forming one character.
    let flag = "🇺🇸"
    XCTAssertEqual(truncate(flag, 4), "")
    XCTAssertEqual(truncate(flag + flag, 12), flag)
  }

  func testSkinToneModifierIsKeptWhole() {
    let wave = "👋🏽"
    XCTAssertEqual(wave.count, 1)
    XCTAssertEqual(truncate(wave, 4), "")
    XCTAssertEqual(truncate(wave, 8), wave)
  }

  func testCRLFIsKeptWhole() {
    // "\r\n" is a single character, so the cut cannot fall between "\r" and "\n".
    XCTAssertEqual(truncate("a\r\nb", 2), "a")
    XCTAssertEqual(truncate("a\r\nb", 3), "a\r\n")
  }

  func testCharacterLargerThanTheLimitYieldsEmptyString() {
    XCTAssertEqual(truncate("👨‍👩‍👧 and more", 10), "")
  }

  // MARK: - Input representation

  func testBridgedNSStringIsTruncatedLikeANativeString() {
    let native = "crash: é€😀👨‍👩‍👧 \r\n trailing"
    let bridged = NSString(string: native) as String
    for limit in 0 ... native.utf8.count + 1 {
      XCTAssertEqual(truncate(bridged, limit), truncate(native, limit), "maxBytes \(limit)")
    }
  }

  func testTruncatedResultIsAValidStandaloneString() {
    let result = truncate("abc😀def", 5)
    XCTAssertEqual(result, "abc")
    XCTAssertEqual(String(decoding: Array(result.utf8), as: UTF8.self), result)
  }

  // MARK: - Contract over many inputs

  func testContractHoldsForEveryLimit() {
    let inputs = [
      "",
      "ascii only",
      "aé€😀",
      "e\u{301}e\u{301}e\u{301}",
      "👨‍👩‍👧👋🏽🇺🇸",
      "line\r\nline\r\n",
      String(repeating: "aé😀", count: 50)
    ]
    for input in inputs {
      for limit in -1 ... input.utf8.count + 1 {
        assertTruncationContract(input, limit)
      }
    }
  }

  func testContractHoldsForRandomStrings() {
    // Fixed seed so a failure always reproduces.
    var generator = SplitMix64(seed: 0x5EED)
    let pieces = ["a", "Z", " ", "\n", "\r\n", "é", "e\u{301}", "€", "😀", "👋🏽", "🇺🇸", "👨‍👩‍👧", "中", "\u{0}"]
    for _ in 0 ..< 200 {
      let length = Int.random(in: 0 ... 30, using: &generator)
      let input = (0 ..< length).map { _ in pieces.randomElement(using: &generator)! }.joined()
      let limit = Int.random(in: 0 ... input.utf8.count + 2, using: &generator)
      assertTruncationContract(input, limit)
    }
  }

  func testLargeReportIsCappedAtTheLimit() {
    // The previously tested size and limits, kept alongside the contract checks above.
    let report = String(repeating: "aé😀", count: 1000)
    for limit in [0, 1, 2, 3, 5, 7, 100, 1023] {
      XCTAssertLessThanOrEqual(truncate(report, limit).utf8.count, limit)
    }
    XCTAssertEqual(truncate(report, 25 * 1024), report, "a report under the default cap is kept whole")
  }
}

/// Small seedable generator so the randomized test is deterministic.
private struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
