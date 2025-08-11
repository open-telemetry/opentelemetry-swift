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
      let mock = MockOperatingSystemDataSource(type: "darwin", description: "iOS Version 15.0 (Build 19A339)",
                                               name: "iOS", version: "15.0.2")
      let provider = OSResourceProvider(source: mock)

      let resource = provider.create()

      XCTAssertEqual(mock.type, resource.attributes["os.type"]?.description)
      XCTAssertEqual(mock.description, resource.attributes["os.description"]?.description)
      XCTAssertEqual(mock.version, resource.attributes["os.version"]?.description)
      XCTAssertEqual(mock.name, resource.attributes["os.name"]?.description)
    }
  }

#endif // canImport(UIKit)
