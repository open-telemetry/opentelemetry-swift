/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
import Foundation

import OpenTelemetryApi
import OpenTelemetrySdk
@testable import ResourceExtension
import XCTest

class ResourcePropagationTests: XCTestCase {
  func testPropagation() {
    let defaultResource = Resource()
    let appProvider = ApplicationResourceProvider(source: ApplicationDataSource())
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
