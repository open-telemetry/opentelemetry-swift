/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

class TracerProviderSdkTests: XCTestCase {
  var tracerProviderSdk = TracerProviderSdk()

  func testDefaultGet() {
    XCTAssert(tracerProviderSdk.get(instrumentationName: "test") is TracerSdk)
  }

  func testgGtSameInstanceForSameName_WithoutVersion() {
    XCTAssert(tracerProviderSdk.get(instrumentationName: "test") === tracerProviderSdk.get(instrumentationName: "test"))
    XCTAssert(tracerProviderSdk.get(instrumentationName: "test") === tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: nil))
  }

  func testPropagatesInstrumentationScopeInfoToTracer() {
    let expected = InstrumentationScopeInfo(name: "theName", version: "theVersion")
    let tracer = tracerProviderSdk.get(instrumentationName: expected.name, instrumentationVersion: expected.version) as! TracerSdk
    XCTAssertEqual(tracer.instrumentationScopeInfo, expected)
  }

  func testGetSameInstanceForSameName_WithVersion() {
    XCTAssert(tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: "version") === tracerProviderSdk.get(instrumentationName: "test", instrumentationVersion: "version"))
  }

  func testGetWithoutName() {
    let tracer = tracerProviderSdk.get(instrumentationName: "") as! TracerSdk
    XCTAssertEqual(tracer.instrumentationScopeInfo.name, TracerProviderSdk.emptyName)
  }
}
