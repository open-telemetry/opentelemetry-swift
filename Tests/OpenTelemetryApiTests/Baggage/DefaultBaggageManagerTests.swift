/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest
import OpenTelemetryTestUtils

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

class DefaultBaggageManagerTestsInfo: OpenTelemetryContextTestCase {
    let defaultBaggageManager = DefaultBaggageManager.instance
    let baggage = TestBaggage()

    override func tearDown() {
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage(), "Test must clean baggage context")
        super.tearDown()
    }
}

class DefaultBaggageManagerTests: DefaultBaggageManagerTestsInfo {
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

    func testWithContextStructured() {
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)
            XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
        }
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
    }
}

#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
class DefaultBaggageManagerConcurrency: DefaultBaggageManagerTestsInfo {
    override var contextManagers: [any ContextManager] {
        Self.concurrencyContextManagers()
    }

    func testWithContextUsingWrap() {
        let expec = expectation(description: "testWithContextUsingWrap")
        let semaphore = DispatchSemaphore(value: 0)
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
            Task {
                XCTAssert(self.defaultBaggageManager.getCurrentBaggage() === self.baggage)
                expec.fulfill()
            }
        }

        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
#endif

class DefaultBaggageManagerTestsImperative: DefaultBaggageManagerTestsInfo {
    override var contextManagers: [any ContextManager] {
        Self.imperativeContextManagers()
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
