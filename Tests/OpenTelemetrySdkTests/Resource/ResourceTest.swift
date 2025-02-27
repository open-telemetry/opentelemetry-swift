/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

class ResourceTest: XCTestCase {
  var defaultResource = Resource(attributes: [String: AttributeValue]())
  var resource1: Resource!
  var resource2: Resource!

  override func setUp() {
    let labelMap1 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
    let labelMap2 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
    resource1 = Resource(attributes: labelMap1)
    resource2 = Resource(attributes: labelMap2)
  }

  func testCreate() {
    let labelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
    let resource = Resource(attributes: labelMap)
    XCTAssertEqual(resource.attributes.count, 2)
    XCTAssertEqual(resource.attributes, labelMap)
    let resource1 = Resource(attributes: [String: AttributeValue]())
    XCTAssertEqual(resource1.attributes.count, 0)
  }

  func testResourceEquals() {
    let labelMap1 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
    let labelMap2 = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
    XCTAssertEqual(Resource(attributes: labelMap1), Resource(attributes: labelMap1))
    XCTAssertNotEqual(Resource(attributes: labelMap1), Resource(attributes: labelMap2))
  }

  func testMergeResources() {
    let expectedLabelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("3"), "c": AttributeValue.string("4")]
    let resource = defaultResource.merging(other: resource1).merging(other: resource2)
    XCTAssertEqual(resource.attributes, expectedLabelMap)
  }

  func testMergeResources_Resource1() {
    let expectedLabelMap = ["a": AttributeValue.string("1"), "b": AttributeValue.string("2")]
    let resource = defaultResource.merging(other: resource1)
    XCTAssertEqual(resource.attributes, expectedLabelMap)
  }
}
