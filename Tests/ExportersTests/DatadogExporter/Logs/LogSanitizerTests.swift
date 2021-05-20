/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class LogSanitizerTests: XCTestCase {
    // MARK: - Attributes sanitization

    func testWhenUserAttributeUsesReservedName_itIsIgnored() {
        let log = DDLog.mockWith(
            attributes: .mockWith(
                userAttributes: [
                    // reserved attributes:
                    "host": mockValue(),
                    "message": mockValue(),
                    "status": mockValue(),
                    "service": mockValue(),
                    "source": mockValue(),
                    "ddtags": mockValue(),

                    // valid attributes:
                    "attribute1": mockValue(),
                    "attribute2": mockValue(),
                    "date": mockValue(),
                ]
            )
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.attributes.userAttributes.count, 3)
        XCTAssertNotNil(sanitized.attributes.userAttributes["attribute1"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["attribute2"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["date"])
    }

    func testWhenUserAttributeNameExceeds10NestedLevels_itIsEscapedByUnderscore() {
        let log = DDLog.mockWith(
            attributes: .mockWith(
                userAttributes: [
                    "one": mockValue(),
                    "one.two": mockValue(),
                    "one.two.three": mockValue(),
                    "one.two.three.four": mockValue(),
                    "one.two.three.four.five": mockValue(),
                    "one.two.three.four.five.six": mockValue(),
                    "one.two.three.four.five.six.seven": mockValue(),
                    "one.two.three.four.five.six.seven.eight": mockValue(),
                    "one.two.three.four.five.six.seven.eight.nine": mockValue(),
                    "one.two.three.four.five.six.seven.eight.nine.ten": mockValue(),
                    "one.two.three.four.five.six.seven.eight.nine.ten.eleven": mockValue(),
                    "one.two.three.four.five.six.seven.eight.nine.ten.eleven.twelve": mockValue(),
                ]
            )
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.attributes.userAttributes.count, 12)
        XCTAssertNotNil(sanitized.attributes.userAttributes["one"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six.seven"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six.seven.eight"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six.seven.eight.nine.ten"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six.seven.eight.nine.ten_eleven"])
        XCTAssertNotNil(sanitized.attributes.userAttributes["one.two.three.four.five.six.seven.eight.nine.ten_eleven_twelve"])
    }

    func testWhenUserAttributeNameIsInvalid_itIsIgnored() {
        let log = DDLog.mockWith(
            attributes: .mockWith(
                userAttributes: [
                    "valid-name": mockValue(),
                    "": mockValue(), // invalid name
                ]
            )
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.attributes.userAttributes.count, 1)
        XCTAssertNotNil(sanitized.attributes.userAttributes["valid-name"])
    }

    func testWhenNumberOfUserAttributesExceedsLimit_itDropsExtraOnes() {
        let mockAttributes = (0...1_000).map { index in ("attribute-\(index)", mockValue()) }
        let log = DDLog.mockWith(
            attributes: .mockWith(
                userAttributes: Dictionary(uniqueKeysWithValues: mockAttributes)
            )
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.attributes.userAttributes.count, LogSanitizer.Constraints.maxNumberOfAttributes)
    }

    func testInternalAttributesAreNotSanitized() {
        let log = DDLog.mockWith(
            attributes: .mockWith(
                internalAttributes: [
                    // reserved attributes:
                    DDLog.TracingAttributes.traceID: mockValue(),
                    DDLog.TracingAttributes.spanID: mockValue(),

                    // custom attribute:
                    "attribute1": mockValue(),
                ]
            )
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.attributes.internalAttributes?.count, 3)
    }

    // MARK: - Tags sanitization

    func testWhenTagHasUpperCasedCharacters_itGetsLowerCased() {
        let log = DDLog.mockWith(
            tags: ["abcd", "Abcdef:ghi", "ABCDEF:GHIJK", "ABCDEFGHIJK"]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags, ["abcd", "abcdef:ghi", "abcdef:ghijk", "abcdefghijk"])
    }

    func testWhenTagStartsWithIllegalCharacter_itIsIgnored() {
        let log = DDLog.mockWith(
            tags: ["?invalid", "valid", "&invalid", ".abcdefghijk", ":abcd"]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags, ["valid"])
    }

    func testWhenTagContainsIllegalCharacter_itIsConvertedToUnderscore() {
        let log = DDLog.mockWith(
            tags: ["this&needs&underscore", "this*as*well", "this/doesnt", "tag with whitespaces"]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags, ["this_needs_underscore", "this_as_well", "this/doesnt", "tag_with_whitespaces"])
    }

    func testWhenTagContainsTrailingCommas_itItTruncatesThem() {
        let log = DDLog.mockWith(
            tags: ["with-one-comma:", "with-several-commas::::", "with-comma:in-the-middle"]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags, ["with-one-comma", "with-several-commas", "with-comma:in-the-middle"])
    }

    func testWhenTagExceedsLengthLimit_itIsTruncated() {
        let log = DDLog.mockWith(
            tags: [.mockRepeating(character: "a", times: 2 * LogSanitizer.Constraints.maxTagLength)]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(
            sanitized.tags,
            [.mockRepeating(character: "a", times: LogSanitizer.Constraints.maxTagLength)]
        )
    }

    func testWhenTagUsesReservedKey_itIsIgnored() {
        let log = DDLog.mockWith(
            tags: ["host:abc", "device:abc", "source:abc", "service:abc", "valid"]
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags, ["valid"])
    }

    func testWhenNumberOfTagsExceedsLimit_itDropsExtraOnes() {
        let mockTags = (0...1_000).map { index in "tag\(index)" }
        let log = DDLog.mockWith(
            tags: mockTags
        )

        let sanitized = LogSanitizer().sanitize(log: log)

        XCTAssertEqual(sanitized.tags?.count, LogSanitizer.Constraints.maxNumberOfTags)
    }

    // MARK: - Private

    private func mockValue() -> String {
        return .mockAny()
    }
}
