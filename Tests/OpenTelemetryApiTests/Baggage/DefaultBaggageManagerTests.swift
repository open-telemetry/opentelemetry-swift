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

#if canImport(os.activity)
class DefaultBaggageManagerTestsActivity: DefaultBaggageManagerTestsServiceContext {
    override class var contextManager: ContextManager {
        ActivityContextManager()
    }

    // This test can't succeed without the os.activity based context propagator since it uses a dispatch queue
    func testWithContextUsingWrap() {
        let expec = expectation(description: "testWithContextUsingWrap")
        let semaphore = DispatchSemaphore(value: 0)

        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)

            let semaphore2 = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                XCTAssert(self.defaultBaggageManager.getCurrentBaggage() === self.baggage)
                semaphore2.signal()
                semaphore.wait()
                XCTAssertNil(self.defaultBaggageManager.getCurrentBaggage())
                expec.fulfill()
            }
            semaphore2.wait()
        }
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        semaphore.signal()
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
#endif

class DefaultBaggageManagerTestsServiceContext: ContextManagerTestCase {
    override class var contextManager: ContextManager {
        ServiceContextManager()
    }

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
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
        }
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
    }
}
