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

final class TraceStateTests: XCTestCase {
    let first_key = "key_1"
    let second_key = "key_2"
    let first_value = "value_1"
    let second_value = "value_2"

    var empty: TraceState!
    var firstTraceState: TraceState!
    var secondTraceState: TraceState!
    var multiValueTraceState: TraceState!

    override func setUp() {
        empty = TraceState()
        firstTraceState = empty.setting(key: first_key, value: first_value)
        secondTraceState = empty.setting(key: second_key, value: second_value)
        multiValueTraceState = empty.setting(key: first_key, value: first_value).setting(key: second_key, value: second_value)
    }

    func testGet() {
        XCTAssertEqual(firstTraceState.get(key: first_key), first_value)
        XCTAssertEqual(secondTraceState.get(key: second_key), second_value)
        XCTAssertEqual(multiValueTraceState.get(key: first_key), first_value)
        XCTAssertEqual(multiValueTraceState.get(key: second_key), second_value)
    }

    func testGetEntries() {
        XCTAssertEqual(firstTraceState.entries, [TraceState.Entry(key: first_key, value: first_value)!])
        XCTAssertEqual(secondTraceState.entries, [TraceState.Entry(key: second_key, value: second_value)!])
        XCTAssertEqual(multiValueTraceState.entries, [TraceState.Entry(key: first_key, value: first_value)!, TraceState.Entry(key: second_key, value: second_value)!])
    }

    func testDisallowsEmptyKey() {
        XCTAssertNil(TraceState.Entry(key: "", value: first_value))
    }

    func testInvalidFirstKeyCharacter() {
        XCTAssertNil(TraceState.Entry(key: "$_key", value: first_value))
    }

    func testFirstKeyCharacterDigitIsAllowed() {
        let result = TraceState().setting(key: "1_key", value: first_value)
        XCTAssertEqual(result.get(key: "1_key"), first_value)
    }

    func testInvalidKeyCharacters() {
        XCTAssertNil(TraceState.Entry(key: "kEy_1", value: first_value))
    }

    func testValidAtSignVendorNamePrefix() {
        let result = TraceState().setting(key: "1@nr", value: first_value)
        XCTAssertEqual(result.get(key: "1@nr"), first_value)
    }

    func testMultipleAtSignNotAllowed() {
        XCTAssertNil(TraceState.Entry(key: "1@n@r@", value: first_value))
    }

    func testInvalidKeySize() {
        let bigString = String(repeating: "a", count: 257)
        XCTAssertNil(TraceState.Entry(key: bigString, value: first_value))
    }

    func testAllAllowedKeyCharacters() {
        let allowedChars = "abcdefghijklmnopqrstuvwxyz0123456789_-*/"
        let result = TraceState().setting(key: allowedChars, value: first_value)
        XCTAssertEqual(result.get(key: allowedChars), first_value)
    }

    func testValueCannotContainEqual() {
        XCTAssertNil(TraceState.Entry(key: first_key, value: "my_value=5"))
    }

    func testValueCannotContainComma() {
        XCTAssertNil(TraceState.Entry(key: first_key, value: "first,second"))
    }

    func testValueCannotContainTrailingSpaces() {
        XCTAssertNil(TraceState.Entry(key: first_key, value: "first "))
    }

    func testInvalidValueSize() {
        let bigString = String(repeating: "a", count: 257)
        XCTAssertNil(TraceState.Entry(key: first_key, value: bigString))
    }

    func testAllAllowedValueCharacters() {
        var validCharacters = String()
        for i in 0x20 ... 0x7E {
            let char = Character(UnicodeScalar(i)!)
            if char == "," || char == "=" {
                continue
            }
            validCharacters.append(Character(UnicodeScalar(i)!))
        }
        let result = TraceState().setting(key: first_key, value: validCharacters)
        XCTAssertEqual(result.get(key: first_key), validCharacters)
    }

    func testAddEntry() {
        XCTAssertEqual(firstTraceState.setting(key: second_key, value: second_value), multiValueTraceState)
    }

    func testUpdateEntry() {
        XCTAssertEqual(firstTraceState.setting(key: first_key, value: second_value).get(key: first_key), second_value)

        let updatedMultiValueTraceState = multiValueTraceState.setting(key: first_key, value: second_value)
        XCTAssertEqual(updatedMultiValueTraceState.get(key: first_key), second_value)
        XCTAssertEqual(updatedMultiValueTraceState.get(key: second_key), second_value)
    }

    func testAddAndUpdateEntry() {
        XCTAssertEqual(firstTraceState.setting(key: first_key, value: second_value).setting(key: second_key, value: first_value).entries,
                       [TraceState.Entry(key: first_key, value: second_value)!, TraceState.Entry(key: second_key, value: first_value)!])
    }

    func testAddSameKey() {
        XCTAssertEqual(firstTraceState.setting(key: first_key, value: second_value).setting(key: first_key, value: first_value).entries,
                       [TraceState.Entry(key: first_key, value: first_value)!])
    }

    func testRemove() {
        XCTAssertEqual(multiValueTraceState.removing(key: second_key), firstTraceState)
    }

    func testAddAndRemoveEntry() {
        XCTAssertEqual(TraceState().setting(key: first_key, value: second_value).removing(key: first_key), TraceState())
    }

    func testTraceState_EqualsAndHashCode() {
        XCTAssertEqual(TraceState(), TraceState())
        XCTAssertNotEqual(TraceState(), firstTraceState)
        XCTAssertNotEqual(TraceState(), TraceState().setting(key: first_key, value: first_value))
        XCTAssertNotEqual(TraceState(), secondTraceState)
        XCTAssertNotEqual(TraceState(), TraceState().setting(key: second_key, value: second_value))
        XCTAssertEqual(firstTraceState, TraceState().setting(key: first_key, value: first_value))
        XCTAssertNotEqual(firstTraceState, secondTraceState)
        XCTAssertNotEqual(firstTraceState, TraceState().setting(key: second_key, value: second_value))
        XCTAssertEqual(secondTraceState, TraceState().setting(key: second_key, value: second_value))
    }

    func testTraceState_ToString() {
        XCTAssertEqual("\(TraceState())", "TraceState(entries: [])")
    }

    static var allTests = [
        ("testGet", testGet),
        ("testGetEntries", testGetEntries),
        ("testDisallowsEmptyKey", testDisallowsEmptyKey),
        ("testInvalidFirstKeyCharacter", testInvalidFirstKeyCharacter),
        ("testFirstKeyCharacterDigitIsAllowed", testFirstKeyCharacterDigitIsAllowed),
        ("testInvalidKeyCharacters", testInvalidKeyCharacters),
        ("testValidAtSignVendorNamePrefix", testValidAtSignVendorNamePrefix),
        ("testMultipleAtSignNotAllowed", testMultipleAtSignNotAllowed),
        ("testInvalidKeySize", testInvalidKeySize),
        ("testAllAllowedKeyCharacters", testAllAllowedKeyCharacters),
        ("testValueCannotContainEqual", testValueCannotContainEqual),
        ("testValueCannotContainComma", testValueCannotContainComma),
        ("testValueCannotContainTrailingSpaces", testValueCannotContainTrailingSpaces),
        ("testInvalidValueSize", testInvalidValueSize),
        ("testAllAllowedValueCharacters", testAllAllowedValueCharacters),
        ("testAddEntry", testAddEntry),
        ("testUpdateEntry", testUpdateEntry),
        ("testAddAndUpdateEntry", testAddAndUpdateEntry),
        ("testAddSameKey", testAddSameKey),
        ("testRemove", testRemove),
        ("testAddAndRemoveEntry", testAddAndRemoveEntry),
        ("testTraceState_EqualsAndHashCode", testTraceState_EqualsAndHashCode),
        ("testTraceState_ToString", testTraceState_ToString),
    ]
}
