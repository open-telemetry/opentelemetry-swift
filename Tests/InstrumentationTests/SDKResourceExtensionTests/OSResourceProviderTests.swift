/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation

import OpenTelemetrySdk
@testable import ResourceExtension
import XCTest

#if canImport(UIKit)

    class OSResourceProviderTests: XCTestCase {
        func testContents() {
            let mock = MockOperatingSystemDataSource(type: "swift", description: "test version string")
            let provider = OSResourceProvider(source: mock)

            let resource = provider.create()

            XCTAssertEqual(mock.type, resource.attributes["os.type"]?.description)
            XCTAssertEqual(mock.description, resource.attributes["os.description"]?.description)
        }
    }

#endif // canImport(UIKit)
