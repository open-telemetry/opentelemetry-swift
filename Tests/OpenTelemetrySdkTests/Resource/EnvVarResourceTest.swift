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
    XCTAssertTrue(
      resource.attributes.keys
        .contains(SemanticConventions.Service.name)
    )
    XCTAssertTrue(
      resource.attributes.keys
        .contains(
          SemanticConventions.Telemetry.sdkName
        )
    )
    XCTAssertTrue(
      resource.attributes.keys
        .contains(
          SemanticConventions.Telemetry.sdkLanguage
        )
    )
    XCTAssertTrue(
      resource.attributes.keys
        .contains(
          SemanticConventions.Telemetry.sdkVersion
        )
    )
  }

  func testGetUniqueInstance() {
    let resource = EnvVarResource.get()
    XCTAssertEqual(resource.attributes.count, 4)
    XCTAssertTrue(
      resource.attributes.keys
        .contains(SemanticConventions.Service.name)
    )
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkName))
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkLanguage))
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkVersion))
  }

  func testGetUniqueInstanceConsideringEnvironment() {
    let environment = ["OTEL_RESOURCE_ATTRIBUTES": "unique.key=some.value,another.key=another.value"]
    let resource = EnvVarResource.get(environment: environment)
    XCTAssertEqual(resource.attributes.count, 6)
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Service.name))
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkName))
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkLanguage))
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Telemetry.sdkVersion))

    XCTAssertTrue(resource.attributes.keys.contains("unique.key"))
    XCTAssertEqual(resource.attributes["unique.key"]!, AttributeValue("some.value"))

    XCTAssertTrue(resource.attributes.keys.contains("another.key"))
    XCTAssertEqual(resource.attributes["another.key"]!, AttributeValue("another.value"))
  }

  func testSpecifyingServiceNameViaEnvironment_changesResourceAttributeValue() {
    let environment = ["OTEL_RESOURCE_ATTRIBUTES": "service.name=CustomServiceName"]
    let resource = EnvVarResource.get(environment: environment)
    XCTAssertTrue(resource.attributes.keys.contains(SemanticConventions.Service.name))
    XCTAssertEqual(resource.attributes[SemanticConventions.Service.name], AttributeValue("CustomServiceName"))
  }
}
