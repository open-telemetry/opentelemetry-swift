//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MeterProviderSdkTests: XCTestCase {
  var meterProvider = MeterProviderSdk.builder().build()

  func testGetSameInstanceForName_WithoutVersion() {
    XCTAssert(meterProvider.get(name: "test") as AnyObject === meterProvider.get(name: "test") as AnyObject)
    XCTAssert(meterProvider.get(name: "test") as AnyObject === meterProvider.meterBuilder(name: "test").build() as AnyObject)
  }
}
