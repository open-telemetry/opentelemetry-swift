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

import OpenTelemetryApi
import XCTest

class ScopedBaggageTests: XCTestCase {
    let key1 = EntryKey(name: "key 1")!
    let key2 = EntryKey(name: "key 2")!
    let key3 = EntryKey(name: "key 3")!

    let value1 = EntryValue(string: "value 1")!
    let value2 = EntryValue(string: "value 2")!
    let value3 = EntryValue(string: "value 3")!
    let value4 = EntryValue(string: "value 4")!

    let metadataTest = EntryMetadata(metadata: "test")

    var baggageManager = DefaultBaggageManager.instance

    func testEmptyBaggage() {
        let defaultBaggage = baggageManager.getCurrentBaggage()
        XCTAssertEqual(defaultBaggage.getEntries().count, 0)
        XCTAssertTrue(defaultBaggage is EmptyBaggage)
    }

    func testWithContext() {
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
        let scopedEntries = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        do {
            let scope = baggageManager.withContext(baggage: scopedEntries)
            XCTAssertTrue(baggageManager.getCurrentBaggage() === scopedEntries)
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
    }

    func testCreateBuilderFromCurrentEntries() {
        let scopedDistContext = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        do {
            let scope = baggageManager.withContext(baggage: scopedDistContext)
            let newEntries = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
            XCTAssertEqual(newEntries.getEntries().count, 2)
            XCTAssertEqual(newEntries.getEntries().sorted(), [Entry(key: key1, value: value1, metadata: metadataTest), Entry(key: key2, value: value2, metadata: metadataTest)].sorted())
            XCTAssertTrue(baggageManager.getCurrentBaggage() === scopedDistContext)
            print(scope) // Silence unused warning
        }
    }

    func testSetCurrentEntriesWithBuilder() {
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
        let scopedDistContext = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        do {
            let scope = baggageManager.withContext(baggage: scopedDistContext)
            XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 1)
            XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().first, Entry(key: key1, value: value1, metadata: metadataTest))
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
    }

    func testAddToCurrentEntriesWithBuilder() {
        let scopedDistContext = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        do {
            let scope1 = baggageManager.withContext(baggage: scopedDistContext)
            let innerDistContext = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
            do {
                let scope2 = baggageManager.withContext(baggage: innerDistContext)
                XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().sorted(),
                               [Entry(key: key1, value: value1, metadata: metadataTest),
                                Entry(key: key2, value: value2, metadata: metadataTest)].sorted())

                XCTAssertTrue(baggageManager.getCurrentBaggage() === innerDistContext)
                print(scope2) // Silence unused warning
            }
            XCTAssertTrue(baggageManager.getCurrentBaggage() === scopedDistContext)
            print(scope1) // Silence unused warning
        }
    }

    func testMultiScopeBaggageWithMetadata() {
        let scopedDistContext = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest)
            .put(key: key2, value: value2, metadata: metadataTest)
            .build()

        do {
            let scope1 = baggageManager.withContext(baggage: scopedDistContext)

            let innerDistContext = baggageManager.baggageBuilder().put(key: key3, value: value3, metadata: metadataTest)
                .put(key: key2, value: value4, metadata: metadataTest)
                .build()
            do {
                let scope2 = baggageManager.withContext(baggage: innerDistContext)
                XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().sorted(),
                               [Entry(key: key1, value: value1, metadata: metadataTest),
                                Entry(key: key2, value: value4, metadata: metadataTest),
                                Entry(key: key3, value: value3, metadata: metadataTest)].sorted())
                XCTAssertTrue(baggageManager.getCurrentBaggage() === innerDistContext)
                print(scope2) // Silence unused warning
            }
            XCTAssertTrue(baggageManager.getCurrentBaggage() === scopedDistContext)
            print(scope1) // Silence unused warning
        }
    }

    func testSetNoParent_doesNotInheritContext() {
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
        let scopedDistContext = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        do {
            let scope = baggageManager.withContext(baggage: scopedDistContext)
            let innerDistContext = baggageManager.baggageBuilder().setNoParent().put(key: key2, value: value2, metadata: metadataTest).build()
            XCTAssertEqual(innerDistContext.getEntries(), [Entry(key: key2, value: value2, metadata: metadataTest)])
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(baggageManager.getCurrentBaggage().getEntries().count, 0)
    }
}
