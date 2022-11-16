/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

private let key = EntryKey(name: "key")!
private let value = EntryValue(string: "value")!

class TestBaggage: Baggage {
    static func baggageBuilder() -> BaggageBuilder {
        EmptyBaggageBuilder()
    }

    func getEntries() -> [Entry] {
        return [Entry(key: key, value: value, metadata: EntryMetadata(metadata: "test"))]
    }

    func getEntryValue(key: EntryKey) -> EntryValue? {
        return value
    }
}

class DefaultBaggageManagerTests: XCTestCase {
    let defaultBaggageManager = DefaultBaggageManager.instance
    let baggage = TestBaggage()

    override func tearDown() {
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage(), "Test must clean baggage context")
    }

    func testBuilderMethod() {
        let builder = defaultBaggageManager.baggageBuilder()
        XCTAssertEqual(builder.build().getEntries().count, 0)
    }

    func testGetCurrentContext_DefaultContext() {
        XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === nil)
    }

    func testGetCurrentContext_ContextSetToNil() {
        let baggage = defaultBaggageManager.getCurrentBaggage()
        XCTAssertNil(baggage)
    }

    func testWithContext() {
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
    }

    func testWithContextUsingWrap() {
        let expec = expectation(description: "testWithContextUsingWrap")
        OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
        XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
        let semaphore = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            XCTAssert(self.defaultBaggageManager.getCurrentBaggage() === self.baggage)
            semaphore2.signal()
            semaphore.wait()
            XCTAssertNil(self.defaultBaggageManager.getCurrentBaggage())
            expec.fulfill()
        }
        semaphore2.wait()
        OpenTelemetry.instance.contextProvider.removeContextForBaggage(baggage)
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        semaphore.signal()
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
