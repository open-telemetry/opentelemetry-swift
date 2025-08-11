/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
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
