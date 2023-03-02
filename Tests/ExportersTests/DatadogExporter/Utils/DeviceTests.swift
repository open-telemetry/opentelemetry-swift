/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS) || os(iOS) || targetEnvironment(macCatalyst)

import XCTest

#if os(iOS)
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

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func testWhenRunningOnMobile_itUsesUIDeviceInfo() {
        let uiDevice = UIDeviceMock(
            model: "model mock",
            systemName: "system name mock",
            systemVersion: "system version mock"
        )
        let device = Device(uiDevice: uiDevice, processInfo: ProcessInfoMock())

        XCTAssertEqual(device.model, uiDevice.model)
        XCTAssertEqual(device.osName, uiDevice.systemName)
        XCTAssertEqual(device.osVersion, uiDevice.systemVersion)
    }

    class ProcessInfoMock: ProcessInfo {}
    #endif
}

#endif
