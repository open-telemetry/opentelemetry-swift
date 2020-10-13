// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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
