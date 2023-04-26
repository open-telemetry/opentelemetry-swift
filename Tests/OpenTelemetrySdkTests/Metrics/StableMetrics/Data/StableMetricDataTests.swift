//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class StableMetricDataTests: XCTestCase {
    func testStableMetricDataCreation() {
        let resource = Resource(attributes: ["foo": AttributeValue("bar")])
        let instrumentationScopeInfo = InstrumentationScopeInfo(name: "test")
        let name = "name"
        let description = "description"
        let unit = "unit"
        let type = MetricDataType.Summary
        let data = StableMetricData.Data(points: [PointData]())

        let metricData = StableMetricData(resource: resource, instrumentationScopeInfo: instrumentationScopeInfo, name: name, description: description, unit: unit, type: type, data: data)
        
        XCTAssertEqual(metricData.resource, resource)
        XCTAssertEqual(metricData.instrumentationScopeInfo, instrumentationScopeInfo)
        XCTAssertEqual(metricData.name, name)
        XCTAssertEqual(metricData.description, description)
        XCTAssertEqual(metricData.unit, unit)
        XCTAssertEqual(metricData.type, type)
        XCTAssertEqual(metricData.data, data)
    }

    func testEmptyStableMetricData() {
        XCTAssertEqual(StableMetricData.empty, StableMetricData(resource: Resource.empty, instrumentationScopeInfo: InstrumentationScopeInfo(), name: "", description: "", unit: "", type: .Summary, data: StableMetricData.Data(points: [PointData]())))
    }
}
