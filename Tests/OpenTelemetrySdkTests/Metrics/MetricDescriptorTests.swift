//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MetricDescriptorTests: XCTestCase {
  func testInitMetricDescriptor() {
    let descriptor = MetricDescriptor(name: "Name", description: "Description", unit: "point")

    XCTAssertEqual("OpenTelemetrySdk.DefaultAggregation", descriptor.aggregationName())

    let viewDescriptor = MetricDescriptor(
      view: View.builder().build(),
      instrument: InstrumentDescriptor(
        name: "Name",
        description: "Description",
        unit: "point",
        type: .observableGauge,
        valueType: .double
      )
    )

    XCTAssertEqual(descriptor, viewDescriptor)
    XCTAssertEqual(descriptor.hashValue, viewDescriptor.hashValue)
    XCTAssertEqual(descriptor.aggregationName(), viewDescriptor.aggregationName())
  }

  func testViews() {
    let descriptor = MetricDescriptor(
      view: View(
        name: "View",
        description: "View Descriptor",
        aggregation: Aggregations.drop(),
        attributeProcessor: NoopAttributeProcessor.noop
      ),
      instrument: InstrumentDescriptor(
        name: "name",
        description: "instrumentDescriptor",
        unit: "ms",
        type: .observableGauge,
        valueType: .double
      )
    )
    XCTAssertEqual(descriptor.name, "View")
    XCTAssertEqual(descriptor.description, "View Descriptor")
  }
}
