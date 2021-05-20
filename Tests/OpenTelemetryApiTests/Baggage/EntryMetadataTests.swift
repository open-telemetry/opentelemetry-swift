/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import XCTest

class EntryMetadataTests: XCTestCase {
    func testGetEntryTtl() {
        let entryMetadata = EntryMetadata(metadata: "test")
        XCTAssertEqual(entryMetadata!.metadata,  "test")
    }

    func testEquals() {
        XCTAssertEqual(EntryMetadata(metadata:  "test"), EntryMetadata(metadata:  "test"))
        XCTAssertNotEqual(EntryMetadata(metadata:  "test1"), EntryMetadata(metadata: "test2"))
    }
}
