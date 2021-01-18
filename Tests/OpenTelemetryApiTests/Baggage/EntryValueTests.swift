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

class EntryValueTests: XCTestCase {
    func testMaxLength() {
        XCTAssertEqual(EntryValue.maxLength, 255)
    }

    func testAsString() {
        XCTAssertEqual(EntryValue(string: "foo")?.string, "foo")
    }

    func testCreate_AllowEntryValueWithMaxLength() {
        let value = String(repeating: "k", count: EntryValue.maxLength)
        XCTAssertEqual(EntryValue(string: value)?.string, value)
    }

    func testCreate_DisallowEntryValueOverMaxLength() {
        let value = String(repeating: "k", count: EntryValue.maxLength + 1)
        XCTAssertNil(EntryValue(string: value)?.string)
    }

    func testDisallowEntryValueWithUnprintableChars() {
        let value = String("\0")
        XCTAssertNil(EntryValue(string: value)?.string)
    }

    func testEntryValueEquals() {
        XCTAssertEqual(EntryValue(string: "foo"), EntryValue(string: "foo"))
        XCTAssertNotEqual(EntryValue(string: "foo"), EntryValue(string: "bar"))
    }
}
