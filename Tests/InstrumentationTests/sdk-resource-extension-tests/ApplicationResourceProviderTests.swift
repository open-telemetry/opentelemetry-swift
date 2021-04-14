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
import OpenTelemetrySdk
import XCTest

@testable import ResourceExtension

    class ApplicationResourceProviderTests: XCTestCase {
        func testContents() {
            let appData = mockApplicationData(name: "appName", identifier: "com.bundle.id", version: "1.2.3", build: "9876")

            let provider = ApplicationResourceProvider(source: appData) as ResourceProvider

            let resource = provider.create()

            XCTAssertEqual(appData.name, resource.attributes[ResourceAttributes.serviceName.rawValue]?.description)
            let versionDescription = resource.attributes[ResourceAttributes.serviceVersion.rawValue]?.description

            XCTAssertNotNil(versionDescription)

            XCTAssertTrue(versionDescription!.hasPrefix(appData.version!))
            XCTAssertTrue(versionDescription!.contains(appData.build!))
        }

        func testNoBundleVersion() {
            let appData = mockApplicationData(name: "appName", identifier: "com.bundle.id", version: "1.2.3", build: nil)

            let provider = ApplicationResourceProvider(source: appData) as ResourceProvider

            let resource = provider.create()

            XCTAssertEqual(appData.name, resource.attributes[ResourceAttributes.serviceName.rawValue]?.description)
            let versionDescription = resource.attributes[ResourceAttributes.serviceVersion.rawValue]?.description

            XCTAssertNotNil(versionDescription)

            XCTAssertEqual(versionDescription, appData.version)
        }

        func testNoShortVersion() {
            let appData = mockApplicationData(name: "appName", identifier: "com.bundle.id", version: nil, build: "3456")

            let provider = ApplicationResourceProvider(source: appData) as ResourceProvider

            let resource = provider.create()

            XCTAssertEqual(appData.name, resource.attributes[ResourceAttributes.serviceName.rawValue]?.description)
            let versionDescription = resource.attributes[ResourceAttributes.serviceVersion.rawValue]?.description

            XCTAssertNotNil(versionDescription)
            XCTAssertEqual(versionDescription, appData.build)
        }

        func testNoAppData() {
            let appData = mockApplicationData(name: nil, identifier: nil, version: nil, build: nil)

            let provider = ApplicationResourceProvider(source: appData) as ResourceProvider

            let resource = provider.create()

            XCTAssertEqual(resource.attributes.count, 0)
        }
    }

