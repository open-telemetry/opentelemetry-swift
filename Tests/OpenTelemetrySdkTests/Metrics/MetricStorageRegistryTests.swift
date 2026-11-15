//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

private class TestMetricStorage: MetricStorage {
  let metricDescriptor: MetricDescriptor

  init(name: String, description: String = "", unit: String = "") {
    metricDescriptor = MetricDescriptor(name: name, description: description, unit: unit)
  }

  func collect(resource: Resource, scope: InstrumentationScopeInfo, startEpochNanos: UInt64, epochNanos: UInt64) -> MetricData {
    return MetricData.empty
  }

  func isEmpty() -> Bool {
    return true
  }
}

class MetricStorageRegistryTests: XCTestCase {
  func testRegisterReturnsExistingStorageForIdenticalDescriptor() {
    let registry = MetricStorageRegistry()
    let storage = TestMetricStorage(name: "counter")
    let identical = TestMetricStorage(name: "counter")

    XCTAssert(registry.register(newStorage: storage) as AnyObject === storage as AnyObject)
    XCTAssert(registry.register(newStorage: identical) as AnyObject === storage as AnyObject)
    XCTAssertEqual(registry.getStorages().count, 1)
  }

  func testRegisterKeepsConflictingStorages() {
    let registry = MetricStorageRegistry()
    let storage = TestMetricStorage(name: "counter", unit: "ms")
    let conflicting = TestMetricStorage(name: "counter", unit: "s")

    XCTAssert(registry.register(newStorage: storage) as AnyObject === storage as AnyObject)
    XCTAssert(registry.register(newStorage: conflicting) as AnyObject === conflicting as AnyObject)
    XCTAssertEqual(registry.getStorages().count, 2)
  }
}
