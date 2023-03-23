//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

@testable import OpenTelemetrySdk
import XCTest

class StableMeterProviderSdkTests : XCTestCase {
    var meterProvider = StableMeterProviderBuilder().build()
    
    func testDefaultGet() {
        XCTAssert(meterProvider.get(name: "test") is StableMeterSdk)
    }
}
