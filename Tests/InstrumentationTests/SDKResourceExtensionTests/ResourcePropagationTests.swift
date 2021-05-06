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

class ResourcePropagationTests : XCTestCase {
    func testPropagation() {
        let defaultResource = Resource()
        let appProvider = ApplicationResourceProvider(source: ApplicationDataSource())
        let telemetryProvider = TelemetryResourceProvider(source: TelemetryDataSource())
        let resultResource = DefaultResources().get()
        
        let defaultValue = defaultResource.attributes[ResourceAttributes.serviceName.rawValue]?.description
        let resultValue = resultResource.attributes[ResourceAttributes.serviceName.rawValue]?.description
        let applicationName = appProvider.attributes[ResourceAttributes.serviceName.rawValue]?.description
        
        
        XCTAssertNotNil(defaultValue)
        XCTAssertNotNil(resultValue)
        XCTAssertNotNil(applicationName)
        XCTAssertEqual(resultValue, applicationName)
        XCTAssertNotEqual(resultValue, defaultValue)
        
        
    }
}
