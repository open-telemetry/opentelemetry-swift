/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class EnvVarResourceTest: XCTestCase {
    func testDefaultSharedInstance() {
        let resource = EnvVarResource.resource
        XCTAssertEqual(resource.attributes.count, 4)
        XCTAssertTrue(resource.attributes.keys.contains("service.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.language"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.version"))
    }

    func testGetUniqueInstance() {
        let resource = EnvVarResource.get()
        XCTAssertEqual(resource.attributes.count, 4)
        XCTAssertTrue(resource.attributes.keys.contains("service.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.language"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.version"))
    }

    func testGetUniqueInstanceConsideringEnvironment() {
        let environment = [ "OTEL_RESOURCE_ATTRIBUTES": "unique.key=some.value,another.key=another.value"]
        let resource = EnvVarResource.get(environment: environment)
        XCTAssertEqual(resource.attributes.count, 6)
        XCTAssertTrue(resource.attributes.keys.contains("service.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.name"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.language"))
        XCTAssertTrue(resource.attributes.keys.contains("telemetry.sdk.version"))

        XCTAssertTrue(resource.attributes.keys.contains("unique.key"))
        XCTAssertEqual(resource.attributes["unique.key"]!, AttributeValue("some.value"))

        XCTAssertTrue(resource.attributes.keys.contains("another.key"))
        XCTAssertEqual(resource.attributes["another.key"]!, AttributeValue("another.value"))
    }
}
