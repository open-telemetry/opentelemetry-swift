/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import ResourceExtension
import XCTest

class TelemetryResourceProviderTests: XCTestCase {
  func testAll() {
    let resources = DefaultResources().get()
    print("\(resources)")
  }

  func testContents() {
    let mock = MockTelemetryDataSource(name: "testAgent", language: "swift", version: "1.2.3")
    let provider = TelemetryResourceProvider(source: mock)

    let resource = provider.create()

    XCTAssertEqual(mock.name, resource.attributes["telemetry.sdk.name"]?.description)
    XCTAssertEqual(mock.language, resource.attributes["telemetry.sdk.language"]?.description)
    XCTAssertEqual(mock.version, resource.attributes["telemetry.sdk.version"]?.description)
  }

  func testNils() {
    let mock = MockTelemetryDataSource(name: "testAgent", language: "swift", version: nil)
    let provider = TelemetryResourceProvider(source: mock)

    let resource = provider.create()

    XCTAssertEqual(mock.name, resource.attributes["telemetry.sdk.name"]?.description)
    XCTAssertEqual(mock.language, resource.attributes["telemetry.sdk.language"]?.description)
    XCTAssertNil(resource.attributes["telemetry.sdk.version"])
  }
}
