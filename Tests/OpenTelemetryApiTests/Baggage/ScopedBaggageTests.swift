/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest
import OpenTelemetryTestUtils

class ScopedBaggageTestsInfo: OpenTelemetryContextTestCase {
    let key1 = EntryKey(name: "key 1")!
    let key2 = EntryKey(name: "key 2")!
    let key3 = EntryKey(name: "key 3")!

    let value1 = EntryValue(string: "value 1")!
    let value2 = EntryValue(string: "value 2")!
    let value3 = EntryValue(string: "value 3")!
    let value4 = EntryValue(string: "value 4")!

    let metadataTest = EntryMetadata(metadata: "test")

    var baggageManager = DefaultBaggageManager.instance

    override func tearDown() {
        if baggageManager.getCurrentBaggage() != nil {
            XCTAssert(false, "Test must clean baggage context")
        }
    }
}

class ScopedBaggageTests: ScopedBaggageTestsInfo {
    func testEmptyBaggage() {
        let defaultBaggage = baggageManager.getCurrentBaggage()
        XCTAssertNil(defaultBaggage)
    }

    func testCreateBuilderFromCurrentEntries() {
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            let newEntries = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
            XCTAssertEqual(newEntries.getEntries().count, 2)
            XCTAssertEqual(newEntries.getEntries().sorted(), [Entry(key: key1, value: value1, metadata: metadataTest), Entry(key: key2, value: value2, metadata: metadataTest)].sorted())
            XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage)
        }
    }

    func testSetCurrentEntriesWithBuilder() {
        XCTAssertNil(baggageManager.getCurrentBaggage())
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().count, 1)
            XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().first, Entry(key: key1, value: value1, metadata: metadataTest))
        }
        XCTAssertNil(baggageManager.getCurrentBaggage())
    }

    func testAddToCurrentEntriesWithBuilder() {
        let outerBaggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.withActiveBaggage(outerBaggage) {
            let innerBaggage = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
            OpenTelemetry.instance.contextProvider.withActiveBaggage(innerBaggage) {
                XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().sorted(),
                               [Entry(key: key1, value: value1, metadata: metadataTest),
                                Entry(key: key2, value: value2, metadata: metadataTest)].sorted())

                XCTAssertTrue(baggageManager.getCurrentBaggage() === innerBaggage)
            }
            XCTAssertTrue(baggageManager.getCurrentBaggage() === outerBaggage)
        }
    }

    func testMultiScopeBaggageWithMetadata() {
        let baggage1 = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest)
            .put(key: key2, value: value2, metadata: metadataTest)
            .build()
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage1) {
            let baggage2 = baggageManager.baggageBuilder().put(key: key3, value: value3, metadata: metadataTest)
                .put(key: key2, value: value4, metadata: metadataTest)
                .build()
            OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage2) {
                XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().sorted(),
                               [Entry(key: key1, value: value1, metadata: metadataTest),
                                Entry(key: key2, value: value4, metadata: metadataTest),
                                Entry(key: key3, value: value3, metadata: metadataTest)].sorted())
                XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage2)
            }
            XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage1)
        }
    }

    func testSetNoParent_doesNotInheritContext() {
        XCTAssertNil(baggageManager.getCurrentBaggage())
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            let innerDistContext = baggageManager.baggageBuilder().setNoParent().put(key: key2, value: value2, metadata: metadataTest).build()
            XCTAssertEqual(innerDistContext.getEntries(), [Entry(key: key2, value: value2, metadata: metadataTest)])
        }
        XCTAssertNil(baggageManager.getCurrentBaggage())
    }
}

final class ScopedBaggageTestsImperative: ScopedBaggageTestsInfo {
    override var contextManagers: [any ContextManager] {
        Self.imperativeContextManagers()
    }

    func testCreateBuilderFromCurrentEntries() {
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        let newEntries = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
        XCTAssertEqual(newEntries.getEntries().count, 2)
        XCTAssertEqual(newEntries.getEntries().sorted(), [Entry(key: key1, value: value1, metadata: metadataTest), Entry(key: key2, value: value2, metadata: metadataTest)].sorted())
        XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
    }

    func testSetCurrentEntriesWithBuilder() {
        XCTAssertNil(baggageManager.getCurrentBaggage())
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().count, 1)
        XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().first, Entry(key: key1, value: value1, metadata: metadataTest))
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
        XCTAssertNil(baggageManager.getCurrentBaggage())
    }

    func testAddToCurrentEntriesWithBuilder() {
        let outerBaggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(outerBaggage)
        let innerBaggage = baggageManager.baggageBuilder().put(key: key2, value: value2, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(innerBaggage)
        XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().sorted(),
                       [Entry(key: key1, value: value1, metadata: metadataTest),
                        Entry(key: key2, value: value2, metadata: metadataTest)].sorted())

        XCTAssertTrue(baggageManager.getCurrentBaggage() === innerBaggage)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(innerBaggage)
        XCTAssertTrue(baggageManager.getCurrentBaggage() === outerBaggage)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(outerBaggage)
    }

    func testMultiScopeBaggageWithMetadata() {
        let baggage1 = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest)
            .put(key: key2, value: value2, metadata: metadataTest)
            .build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage1)

        let baggage2 = baggageManager.baggageBuilder().put(key: key3, value: value3, metadata: metadataTest)
            .put(key: key2, value: value4, metadata: metadataTest)
            .build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage2)

        XCTAssertEqual(baggageManager.getCurrentBaggage()?.getEntries().sorted(),
                       [Entry(key: key1, value: value1, metadata: metadataTest),
                        Entry(key: key2, value: value4, metadata: metadataTest),
                        Entry(key: key3, value: value3, metadata: metadataTest)].sorted())
        XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage2)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage2)

        XCTAssertTrue(baggageManager.getCurrentBaggage() === baggage1)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage1)
    }

    func testSetNoParent_doesNotInheritContext() {
        XCTAssertNil(baggageManager.getCurrentBaggage())
        let baggage = baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).build()
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        XCTAssertIdentical(OpenTelemetry.instance.contextProvider.activeBaggage, baggage)
        let innerDistContext = baggageManager.baggageBuilder().setNoParent().put(key: key2, value: value2, metadata: metadataTest).build()
        XCTAssertEqual(innerDistContext.getEntries(), [Entry(key: key2, value: value2, metadata: metadataTest)])
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
        XCTAssertNil(baggageManager.getCurrentBaggage())
    }
}
