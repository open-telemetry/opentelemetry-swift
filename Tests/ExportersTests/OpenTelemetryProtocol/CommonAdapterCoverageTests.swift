/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporterCommon
@testable import OpenTelemetrySdk
import XCTest

final class CommonAdapterCoverageTests: XCTestCase {
  func testStringAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .string("v"))
    XCTAssertEqual(kv.key, "k")
    XCTAssertEqual(kv.value.stringValue, "v")
  }

  func testBoolAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .bool(true))
    XCTAssertTrue(kv.value.boolValue)
  }

  func testIntAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .int(42))
    XCTAssertEqual(kv.value.intValue, 42)
  }

  func testDoubleAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .double(3.14))
    XCTAssertEqual(kv.value.doubleValue, 3.14)
  }

  func testSetAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .set(AttributeSet(labels: ["a": .string("1")])))
    XCTAssertEqual(kv.value.kvlistValue.values.count, 1)
    XCTAssertEqual(kv.value.kvlistValue.values.first?.key, "a")
  }

  func testArrayAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k",
                                             attributeValue: .array(AttributeArray(values: [.string("a"), .int(1)])))
    XCTAssertEqual(kv.value.arrayValue.values.count, 2)
  }

  // These four tests exercise the deprecated .stringArray/.boolArray/.intArray/
  // .doubleArray AttributeValue cases that CommonAdapter still handles for
  // backward compatibility. Mark the tests themselves deprecated so building
  // the test bundle stays warning-free while still covering the legacy paths.
  @available(*, deprecated)
  func testStringArrayAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .stringArray(["a", "b"]))
    XCTAssertEqual(kv.value.arrayValue.values.count, 2)
    XCTAssertEqual(kv.value.arrayValue.values.first?.stringValue, "a")
  }

  @available(*, deprecated)
  func testBoolArrayAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .boolArray([true, false]))
    XCTAssertEqual(kv.value.arrayValue.values.count, 2)
    XCTAssertTrue(kv.value.arrayValue.values.first?.boolValue ?? false)
  }

  @available(*, deprecated)
  func testIntArrayAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .intArray([1, 2, 3]))
    XCTAssertEqual(kv.value.arrayValue.values.count, 3)
    XCTAssertEqual(kv.value.arrayValue.values.first?.intValue, 1)
  }

  @available(*, deprecated)
  func testDoubleArrayAttribute() {
    let kv = CommonAdapter.toProtoAttribute(key: "k", attributeValue: .doubleArray([1.0, 2.0]))
    XCTAssertEqual(kv.value.arrayValue.values.count, 2)
    XCTAssertEqual(kv.value.arrayValue.values.first?.doubleValue, 1.0)
  }

  func testProtoAnyValueStringAndArrayNesting() {
    let nested = CommonAdapter.toProtoAnyValue(attributeValue: .array(AttributeArray(values: [.string("a")])))
    XCTAssertEqual(nested.arrayValue.values.first?.stringValue, "a")
  }

  func testProtoAnyValueForAllScalarVariants() {
    XCTAssertEqual(CommonAdapter.toProtoAnyValue(attributeValue: .string("s")).stringValue, "s")
    XCTAssertTrue(CommonAdapter.toProtoAnyValue(attributeValue: .bool(true)).boolValue)
    XCTAssertEqual(CommonAdapter.toProtoAnyValue(attributeValue: .int(5)).intValue, 5)
    XCTAssertEqual(CommonAdapter.toProtoAnyValue(attributeValue: .double(2.5)).doubleValue, 2.5)
  }

  @available(*, deprecated)
  func testProtoAnyValueForAllArrayVariants() {
    XCTAssertEqual(
      CommonAdapter.toProtoAnyValue(attributeValue: .stringArray(["x"])).arrayValue.values.count, 1)
    XCTAssertEqual(
      CommonAdapter.toProtoAnyValue(attributeValue: .boolArray([true])).arrayValue.values.count, 1)
    XCTAssertEqual(
      CommonAdapter.toProtoAnyValue(attributeValue: .intArray([1])).arrayValue.values.count, 1)
    XCTAssertEqual(
      CommonAdapter.toProtoAnyValue(attributeValue: .doubleArray([0.5])).arrayValue.values.count, 1)
    XCTAssertEqual(
      CommonAdapter.toProtoAnyValue(attributeValue: .set(AttributeSet(labels: ["k": .int(1)]))).kvlistValue.values.count, 1)
  }

  func testToProtoInstrumentationScopeWithoutOptionals() {
    let scope = InstrumentationScopeInfo(name: "noopt")
    let proto = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scope)
    XCTAssertEqual(proto.name, "noopt")
    XCTAssertEqual(proto.version, "")
    XCTAssertEqual(proto.attributes.count, 0)
  }

  func testToProtoInstrumentationScopeWithVersionAndAttributes() {
    let scope = InstrumentationScopeInfo(name: "n",
                                         version: "1.2.3",
                                         attributes: ["k": .string("v")])
    let proto = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scope)
    XCTAssertEqual(proto.name, "n")
    XCTAssertEqual(proto.version, "1.2.3")
    XCTAssertEqual(proto.attributes.count, 1)
    XCTAssertEqual(proto.attributes.first?.key, "k")
  }
}
