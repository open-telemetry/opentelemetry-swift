/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

#if !os(macOS)
import UIKit
#else
import Foundation
import SystemConfiguration
#endif

@testable import DatadogExporter

class DeviceTests: XCTestCase {
    func testWhenRunningOnMobile_itReturnsDevice() {
        XCTAssertNotNil(Device.current)
    }

    #if !os(macOS)
    func testWhenRunningOnMobile_itUsesUIDeviceInfo() {
        let uiDevice = DeviceMock(
            model: "model mock",
            systemName: "system name mock",
            systemVersion: "system version mock"
        )
        let device = Device(uiDevice: uiDevice, processInfo: ProcessInfoMock())

        XCTAssertEqual(device.model, uiDevice.model)
        XCTAssertEqual(device.osName, uiDevice.systemName)
        XCTAssertEqual(device.osVersion, uiDevice.systemVersion)
    }
    #endif
}
