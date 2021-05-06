// Copyright 2021, OpenTelemetry Authors
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

        XCTAssertEqual(mock.model, resource.attributes["device.model"]?.description)
        XCTAssertEqual(mock.identifier, resource.attributes[ResourceAttributes.hostId.rawValue]?.description)
    }
}
