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
class DefaultBaggageManagerTestsActivity: DefaultBaggageManagerTestsBase {
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
class DefaultBaggageManagerTestsServiceContext: DefaultBaggageManagerTestsBase {
    override class var contextManager: ContextManager {
        ServiceContextManager()
    }
}

class DefaultBaggageManagerTestsBase: ContextManagerTestCase {
    let defaultBaggageManager = DefaultBaggageManager.instance
    let baggage = TestBaggage()

    override func tearDown() {
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage(), "Test must clean baggage context")
    }

    func testBuilderMethod() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        let builder = defaultBaggageManager.baggageBuilder()
        XCTAssertEqual(builder.build().getEntries().count, 0)
    }

    func testGetCurrentContext_DefaultContext() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === nil)
    }

    func testGetCurrentContext_ContextSetToNil() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        let baggage = defaultBaggageManager.getCurrentBaggage()
        XCTAssertNil(baggage)
    }

    func testWithContext() throws {
        try XCTSkipIf(Self.contextManager is DefaultContextManager)
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
        OpenTelemetry.instance.contextProvider.withActiveBaggage(baggage) {
            XCTAssertTrue(defaultBaggageManager.getCurrentBaggage() === baggage)
        }
        XCTAssertNil(defaultBaggageManager.getCurrentBaggage())
    }
}
