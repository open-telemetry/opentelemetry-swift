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
@testable import OpenTelemetrySdk
import XCTest

class ScopedCorrelationContextTests: XCTestCase {
    let key1 = EntryKey(name: "key 1")!
    let key2 = EntryKey(name: "key 2")!
    let key3 = EntryKey(name: "key 3")!

    let value1 = EntryValue(string: "value 1")!
    let value2 = EntryValue(string: "value 2")!
    let value3 = EntryValue(string: "value 3")!
    let value4 = EntryValue(string: "value 4")!

    let metadataUnlimitedPropagation = EntryMetadata(entryTtl: .unlimitedPropagation)
    let metadataNoPropagation = EntryMetadata(entryTtl: .noPropagation)

    var contextManager = CorrelationContextManagerSdk()

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEmptyCorrelationContext() {
        let defaultCorrelationContext = contextManager.getCurrentContext()
        XCTAssertEqual(defaultCorrelationContext.getEntries().count, 0)
        XCTAssertTrue(defaultCorrelationContext is EmptyCorrelationContext)
    }

    func testWithContext() {
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
        let scopedEntries = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation).build()
        do {
            let scope = contextManager.withContext(distContext: scopedEntries)
            XCTAssertTrue(contextManager.getCurrentContext() === scopedEntries)
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
    }

    func testCreateBuilderFromCurrentEntries() {
        let scopedDistContext = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation).build()
        do {
            let scope = contextManager.withContext(distContext: scopedDistContext)
            let newEntries = contextManager.contextBuilder().put(key: key2, value: value2, metadata: metadataUnlimitedPropagation).build()
            XCTAssertEqual(newEntries.getEntries().count, 2)
            XCTAssertEqual(newEntries.getEntries().sorted(), [Entry(key: key1, value: value1, entryMetadata: metadataUnlimitedPropagation), Entry(key: key2, value: value2, entryMetadata: metadataUnlimitedPropagation)].sorted())
            XCTAssertTrue(contextManager.getCurrentContext() === scopedDistContext)
            print(scope) // Silence unused warning
        }
    }

    func testSetCurrentEntriesWithBuilder() {
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
        let scopedDistContext = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation).build()
        do {
            let scope = contextManager.withContext(distContext: scopedDistContext)
            XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 1)
            XCTAssertEqual(contextManager.getCurrentContext().getEntries().first, Entry(key: key1, value: value1, entryMetadata: metadataUnlimitedPropagation))
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
    }

    func testAddToCurrentEntriesWithBuilder() {
        let scopedDistContext = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation).build()
        do {
            let scope1 = contextManager.withContext(distContext: scopedDistContext)
            let innerDistContext = contextManager.contextBuilder().put(key: key2, value: value2, metadata: metadataUnlimitedPropagation).build()
            do {
                let scope2 = contextManager.withContext(distContext: innerDistContext)
                XCTAssertEqual(contextManager.getCurrentContext().getEntries().sorted(),
                               [Entry(key: key1, value: value1, entryMetadata: metadataUnlimitedPropagation),
                                Entry(key: key2, value: value2, entryMetadata: metadataUnlimitedPropagation)].sorted())

                XCTAssertTrue(contextManager.getCurrentContext() === innerDistContext)
                print(scope2) // Silence unused warning
            }
            XCTAssertTrue(contextManager.getCurrentContext() === scopedDistContext)
            print(scope1) // Silence unused warning
        }
    }

    func testMultiScopeCorrelationContextWithMetadata() {
        let scopedDistContext = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation)
            .put(key: key2, value: value2, metadata: metadataUnlimitedPropagation)
            .build()

        do {
            let scope1 = contextManager.withContext(distContext: scopedDistContext)

            let innerDistContext = contextManager.contextBuilder().put(key: key3, value: value3, metadata: metadataUnlimitedPropagation)
                .put(key: key2, value: value4, metadata: metadataUnlimitedPropagation)
                .build()
            do {
                let scope2 = contextManager.withContext(distContext: innerDistContext)
                XCTAssertEqual(contextManager.getCurrentContext().getEntries().sorted(),
                               [Entry(key: key1, value: value1, entryMetadata: metadataUnlimitedPropagation),
                                Entry(key: key2, value: value4, entryMetadata: metadataUnlimitedPropagation),
                                Entry(key: key3, value: value3, entryMetadata: metadataUnlimitedPropagation)].sorted())
                XCTAssertTrue(contextManager.getCurrentContext() === innerDistContext)
                print(scope2) // Silence unused warning
            }
            XCTAssertTrue(contextManager.getCurrentContext() === scopedDistContext)
            print(scope1) // Silence unused warning
        }
    }

    func testSetNoParent_doesNotInheritContext() {
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
        let scopedDistContext = contextManager.contextBuilder().put(key: key1, value: value1, metadata: metadataUnlimitedPropagation).build()
        do {
            let scope = contextManager.withContext(distContext: scopedDistContext)
            let innerDistContext = contextManager.contextBuilder().setNoParent().put(key: key2, value: value2, metadata: metadataUnlimitedPropagation).build()
            XCTAssertEqual(innerDistContext.getEntries(), [Entry(key: key2, value: value2, entryMetadata: metadataUnlimitedPropagation)])
            print(scope) // Silence unused warning
        }
        XCTAssertEqual(contextManager.getCurrentContext().getEntries().count, 0)
    }
}
