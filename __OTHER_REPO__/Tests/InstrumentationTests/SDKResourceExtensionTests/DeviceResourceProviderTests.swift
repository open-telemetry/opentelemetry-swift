/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import ResourceExtension
import XCTest

class DeviceResourceProviderTests: XCTestCase {
  func testContents() {
    let mock = MockDeviceDataSource(identifier: "00000-0000-000-00000000", model: "testPhone1,0")
    let provider = DeviceResourceProvider(source: mock)

    let resource = provider.create()

    XCTAssertEqual(mock.model, resource.attributes[ResourceAttributes.deviceModelIdentifier.rawValue]?.description)
    XCTAssertEqual(mock.identifier, resource.attributes[ResourceAttributes.deviceId.rawValue]?.description)
  }
}
