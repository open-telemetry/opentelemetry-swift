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

class TelemetryResourceProviderTests: XCTestCase {
    
    func testAll() {
        let resources =  DefaultResources().get()
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
