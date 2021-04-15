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
        if defaultBaggageManager.getCurrentBaggage() != nil {
            XCTAssert(false, "Test must clean baggage context")
        }
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
            semaphore2.signal()
            semaphore.wait()
            XCTAssert(self.defaultBaggageManager.getCurrentBaggage() === self.baggage)
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
