/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class EncodableValueTests: XCTestCase {
    func testItEncodesDifferentEncodableValues() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        XCTAssertEqual(
            try encoder.encode(EncodingContainer(EncodableValue("string"))).utf8String,
            #"{"value":"string"}"#
        )
        XCTAssertEqual(
            try encoder.encode(EncodingContainer(EncodableValue(123))).utf8String,
            #"{"value":123}"#
        )
        XCTAssertEqual(
            try encoder.encode(EncodableValue(["a", "b", "c"])).utf8String,
            #"["a","b","c"]"#
        )
        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(EncodableValue(URL(string: "https://example.com/image.png")!))
            ).utf8String,
            #"{"value":"https:\/\/example.com\/image.png"}"#
        )
        struct Foo: Encodable {
            let bar = "bar_"
            let bizz = "bizz_"
        }
        XCTAssertEqual(
            try encoder.encode(EncodableValue(Foo())).utf8String,
            #"{"bar":"bar_","bizz":"bizz_"}"#
        )
    }
}

class JSONStringEncodableValueTests: XCTestCase {
    func testItEncodesDifferentEncodableValuesAsString() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(JSONStringEncodableValue("string", encodedUsing: encoder))
            ).utf8String,
            #"{"value":"string"}"#
        )
        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(JSONStringEncodableValue(123, encodedUsing: encoder))
            ).utf8String,
            #"{"value":"123"}"#
        )
        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(JSONStringEncodableValue(["a", "b", "c"], encodedUsing: encoder))
            ).utf8String,
            #"{"value":"[\"a\",\"b\",\"c\"]"}"#
        )
        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(
                    JSONStringEncodableValue(URL(string: "https://example.com/image.png")!, encodedUsing: encoder)
                )
            ).utf8String,
            #"{"value":"https:\/\/example.com\/image.png"}"#
        )
        struct Foo: Encodable {
            let bar = "bar_"
            let bizz = "bizz_"
        }
        XCTAssertEqual(
            try encoder.encode(
                EncodingContainer(JSONStringEncodableValue(Foo(), encodedUsing: encoder))
            ).utf8String,
            #"{"value":"{\"bar\":\"bar_\",\"bizz\":\"bizz_\"}"}"#
        )
    }

    func testWhenValueCannotBeEncoded_itThrowsErrorDuringEncoderInvocation() {
        let encoder = JSONEncoder()
        let value = JSONStringEncodableValue(FailingEncodableMock(errorMessage: "ops..."), encodedUsing: JSONEncoder())

        XCTAssertThrowsError(try encoder.encode(value)) { error in
            XCTAssertEqual((error as? ErrorMock)?.description, "ops...")
        }
    }
}
