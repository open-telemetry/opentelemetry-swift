/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class MetricCodableTests: XCTestCase {
    let scope = InstrumentationScopeInfo(name: "lib", version: "semver:0.0.0")
    let resource = Resource(attributes: ["string": .string("string"),
                                         "int": .int(5),
                                         "bool": .bool(true),
                                         "stringArray": .array(AttributeArray(values:[.string("string1"),.string("string2")])),
                                         "intArray": .array(AttributeArray(values:[.int(1),.int(2),.int(3)])),
                                         "boolArray": .array(AttributeArray(values:[.bool(true), .bool(false)]))])
    
    private func generateDoubleSumMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .doubleSum, resource: resource, instrumentationScopeInfo: scope)
        let data = SumData<Double>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 1.5)
        metric.data.append(data)
        return metric
    }
    
    private func generateIntSumMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .intSum, resource: resource, instrumentationScopeInfo: scope)
        let data = SumData<Int>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 1)
        metric.data.append(data)
        return metric
    }
    
    private func generateDoubleSummaryMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .doubleSummary, resource: resource, instrumentationScopeInfo: scope)
        let data = SummaryData<Double>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], count: 2, sum: 2.0, min: 0.5, max: 1.5)
        metric.data.append(data)
        return metric
    }
    
    private func generateIntSummaryMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "metric", desc: "description", type: .intSummary, resource: resource, instrumentationScopeInfo: scope)
        let data = SummaryData<Int>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], count:2, sum: 3, min: 1, max: 2)
        metric.data.append(data)
        return metric
    }

    private func generateDoubleGaugeMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "MyGauge", desc: "description", type: .doubleGauge, resource: Resource(), instrumentationScopeInfo: scope)
        let data = SumData<Double>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 100.5)
        metric.data.append(data)
        return metric
    }
    
    private func generateIntGaugeMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "MyGauge", desc: "description", type: .intGauge, resource: resource, instrumentationScopeInfo: scope)
        let data = SumData<Int>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], sum: 100)
        metric.data.append(data)
        return metric
    }
    
    private func generateDoubleHistogramMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "MyHistogram", desc: "description", type: .doubleHistogram, resource: Resource(), instrumentationScopeInfo: scope)
        let data = HistogramData<Double>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], buckets: (boundaries: [45.25, 55.25], counts: [5, 6]), count:2, sum: 100.5)
        metric.data.append(data)
        return metric
    }
    
    private func generateIntHistogramMetric() -> Metric {
        var metric = Metric(namespace: "namespace", name: "MyHistogram", desc: "description", type: .intHistogram, resource: Resource(), instrumentationScopeInfo: scope)
        let data = HistogramData<Int>(startTimestamp: Date(), timestamp: Date(), labels: ["hello": "world"], buckets: (boundaries: [45, 55], counts: [5, 6]), count:2, sum: 100)
        metric.data.append(data)
        return metric
    }
    
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var testData = generateIntSumMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateDoubleSumMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateIntSummaryMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateDoubleSummaryMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateIntGaugeMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateDoubleGaugeMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateDoubleHistogramMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
        
        testData = generateIntHistogramMetric()
        XCTAssertEqual(testData, try decoder.decode(Metric.self, from: try encoder.encode(testData)))
    }
}
