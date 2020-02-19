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

fileprivate let key = EntryKey(name: "key")!
fileprivate let value = EntryValue(string: "value")!

class TestCorrelationContext: CorrelationContext {
    static func contextBuilder() -> CorrelationContextBuilder {
        EmptyCorrelationContextBuilder()
    }

    func getEntries() -> [Entry] {
        return [Entry(key: key, value: value, entryMetadata: EntryMetadata(entryTtl: .unlimitedPropagation))]
    }

    func getEntryValue(key: EntryKey) -> EntryValue? {
        return value
    }
}

class DefaultCorrelationContextManagerTests: XCTestCase {
    let defaultCorrelationContextManager = DefaultCorrelationContextManager.instance
    let distContext = TestCorrelationContext()

    func testBuilderMethod() {
        let builder = defaultCorrelationContextManager.contextBuilder()
        XCTAssertEqual(builder.build().getEntries().count, 0)
    }

    func testGetCurrentContext_DefaultContext() {
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === EmptyCorrelationContext.instance)
    }

    func testGetCurrentContext_ContextSetToNil() {
        let distContext = defaultCorrelationContextManager.getCurrentContext()
        XCTAssertNotNil(distContext)
        XCTAssertEqual(distContext.getEntries().count, 0)
    }

    func testWithContext() {
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === EmptyCorrelationContext.instance)
        var wtm = defaultCorrelationContextManager.withContext(distContext: distContext)
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === distContext)
        wtm.close()
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === EmptyCorrelationContext.instance)
    }

    func testWithContextUsingWrap() {
        let expec = expectation(description: "testWithContextUsingWrap")
        var wtm = defaultCorrelationContextManager.withContext(distContext: distContext)
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === distContext)
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            semaphore.wait()
            XCTAssertTrue(self.defaultCorrelationContextManager.getCurrentContext() === self.distContext)
            expec.fulfill()
        }
        wtm.close()
        XCTAssertTrue(defaultCorrelationContextManager.getCurrentContext() === EmptyCorrelationContext.instance)
        semaphore.signal()
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
