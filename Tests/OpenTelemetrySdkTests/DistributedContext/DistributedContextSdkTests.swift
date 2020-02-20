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

class CorrelationContextSdkTests: XCTestCase {
    let contextManager = CorrelationContextManagerSdk()

    let tmd = EntryMetadata(entryTtl: .unlimitedPropagation)

    let k1 = EntryKey(name: "k1")!
    let k2 = EntryKey(name: "k2")!

    let v1 = EntryValue(string: "v1")!
    let v2 = EntryValue(string: "v2")!

    var t1: Entry!
    var t2: Entry!

    override func setUp() {
        t1 = Entry(key: k1, value: v1, entryMetadata: tmd)
        t2 = Entry(key: k2, value: v2, entryMetadata: tmd)
    }

    func testGetEntries_empty() {
        let distContext = CorrelationContextSdk.contextBuilder().build()
        XCTAssertEqual(distContext.getEntries().count, 0)
    }

    func testGetEntries_nonEmpty() {
        let distContext = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1, t2])
        XCTAssertEqual(distContext.getEntries().sorted(), [t1, t2].sorted())
    }

    func testGetEntries_chain() {
        let t1alt = Entry(key: k1, value: v2, entryMetadata: tmd)
        let parent = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1, t2])
        let distContext = CorrelationContextSdk.contextBuilder().setParent(parent).put(key: t1alt.key, value: t1alt.value, metadata: t1alt.metadata).build()
        XCTAssertEqual(distContext.getEntries().sorted(), [t1alt, t2].sorted())
    }

    func testPut_newKey() {
        let distContext = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1])
        XCTAssertEqual(contextManager.contextBuilder().setParent(distContext).put(key: k2, value: v2, metadata: tmd).build().getEntries().sorted(), [t1, t2].sorted())
    }

    func testPut_existingKey() {
        let distContext = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1])
        XCTAssertEqual(contextManager.contextBuilder().setParent(distContext).put(key: k1, value: v2, metadata: tmd).build().getEntries(), [Entry(key: k1, value: v2, entryMetadata: tmd)])
    }

    func testPetParent_setNoParent() {
        let parent = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1])
        let distContext = contextManager.contextBuilder().setParent(parent).setNoParent().build()
        XCTAssertEqual(distContext.getEntries().count, 0)
    }

    func testRemove_existingKey() {
        let builder = CorrelationContextSdkBuilder()
        builder.put(key: t1.key, value: t1.value, metadata: t1.metadata)
        builder.put(key: t2.key, value: t2.value, metadata: t2.metadata)
        XCTAssertEqual(builder.remove(key: k1).build().getEntries(), [t2])
    }

    func testRemove_differentKey() {
        let builder = CorrelationContextSdkBuilder()
        builder.put(key: t1.key, value: t1.value, metadata: t1.metadata)
        builder.put(key: t2.key, value: t2.value, metadata: t2.metadata)
        XCTAssertEqual(builder.remove(key: k2).build().getEntries(), [t1])
    }

    func testRemove_keyFromParent() {
        let distContext = CorrelationContextTestUtil.listToCorrelationContext(entries: [t1, t2])
        XCTAssertEqual(contextManager.contextBuilder().setParent(distContext).remove(key: k1).build().getEntries(), [t2])
    }

    func testEquals() {
        XCTAssertEqual(contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v2, metadata: tmd).build() as! CorrelationContextSdk,
                       contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v2, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertEqual(contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v2, metadata: tmd).build() as! CorrelationContextSdk,
                       contextManager.contextBuilder().put(key: k2, value: v2, metadata: tmd).put(key: k1, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertNotEqual(contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v2, metadata: tmd).build() as! CorrelationContextSdk,
                          contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertNotEqual(contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v2, metadata: tmd).build() as! CorrelationContextSdk,
                          contextManager.contextBuilder().put(key: k1, value: v2, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertNotEqual(contextManager.contextBuilder().put(key: k2, value: v2, metadata: tmd).put(key: k1, value: v1, metadata: tmd).build() as! CorrelationContextSdk,
                          contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertNotEqual(contextManager.contextBuilder().put(key: k2, value: v2, metadata: tmd).put(key: k1, value: v1, metadata: tmd).build() as! CorrelationContextSdk,
                          contextManager.contextBuilder().put(key: k1, value: v2, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
        XCTAssertNotEqual(contextManager.contextBuilder().put(key: k1, value: v1, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk,
                          contextManager.contextBuilder().put(key: k1, value: v2, metadata: tmd).put(key: k2, value: v1, metadata: tmd).build() as! CorrelationContextSdk)
    }
}
