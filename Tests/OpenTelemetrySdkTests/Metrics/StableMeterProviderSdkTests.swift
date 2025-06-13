//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class StableMeterProviderSdkTests: XCTestCase {
  var meterProvider = StableMeterProviderSdk.builder().build()

  func testDefaultGet() {
    XCTAssert(meterProvider.get(name: "test") is DefaultStableMeter)
  }

  func testGetSameInstanceForName_WithoutVersion() {
    XCTAssert(meterProvider.get(name: "test") as AnyObject === meterProvider.get(name: "test") as AnyObject)
    XCTAssert(meterProvider.get(name: "test") as AnyObject === meterProvider.meterBuilder(name: "test").build() as AnyObject)
  }
}
