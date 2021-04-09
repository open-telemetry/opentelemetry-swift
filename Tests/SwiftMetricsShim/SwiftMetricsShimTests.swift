// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import CoreMetrics
@testable import SwiftMetricsShim
import XCTest

class SwiftMetricsShimTests: XCTestCase {
    var testProcessor = TestMetricProcessor()
    let provider = MeterProviderSdk()
    var meter: MeterSdk!
    var metrics: OpenTelemetrySwiftMetrics!

    override func setUp() {
        super.setUp()
        testProcessor = TestMetricProcessor()
        
        meter = MeterProviderSdk(
            metricProcessor: testProcessor,
            metricExporter: NoopMetricExporter()
        ).get(instrumentationName: "SwiftMetricsShimTest") as? MeterSdk
        
        metrics = .init(meter: meter)
        MetricsSystem.bootstrapInternal(metrics)
    }
    
    // MARK: - Test Lifecycle
    
    func testDestroy() {
        let handler = metrics.makeCounter(label: "my_label", dimensions: [])
        XCTAssertEqual(metrics.metrics.count, 1)
        
        metrics.destroyCounter(handler)
        XCTAssertEqual(metrics.metrics.count, 0)
    }
    
    // MARK: - Test Metric: Counter
    
    func testCounter() throws {
        let counter = Counter(label: "my_counter")
        counter.increment()
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SumData<Int>)
        XCTAssertEqual(metric.name, "my_counter")
        XCTAssertEqual(metric.aggregationType, .intSum)
        XCTAssertEqual(data.sum, 1)
        XCTAssertNil(data.labels["label_one"])
    }
    
    func testCounter_withLabels() throws {
        let counter = Counter(label: "my_counter", dimensions: [("label_one", "value")])
        counter.increment(by: 5)
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SumData<Int>)
        XCTAssertEqual(metric.name, "my_counter")
        XCTAssertEqual(metric.aggregationType, .intSum)
        XCTAssertEqual(data.sum, 5)
        XCTAssertEqual(data.labels["label_one"], "value")
    }
    
    // MARK: - Test Metric: Gauge
    
    func testGauge() throws {
        let gauge = Gauge(label: "my_gauge")
        gauge.record(100)
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SumData<Double>)
        XCTAssertEqual(metric.name, "my_gauge")
        XCTAssertEqual(metric.aggregationType, .doubleSum)
        XCTAssertEqual(data.sum, 100)
        XCTAssertNil(data.labels["label_one"])
    }
    
    // MARK: - Test Metric: Histogram
    
    func testHistogram() throws {
        let histogram = Gauge(label: "my_histogram", dimensions: [], aggregate: true)
        histogram.record(100)
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SummaryData<Double>)
        XCTAssertEqual(metric.name, "my_histogram")
        XCTAssertEqual(metric.aggregationType, .doubleSummary)
        XCTAssertEqual(data.sum, 100)
        XCTAssertNil(data.labels["label_one"])
    }
    
    // MARK: - Test Metric: Summary
    
    func testSummary() throws {
        let timer = CoreMetrics.Timer(label: "my_timer")
        timer.recordSeconds(1)
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SummaryData<Double>)
        XCTAssertEqual(metric.name, "my_timer")
        XCTAssertEqual(metric.aggregationType, .doubleSummary)
        XCTAssertEqual(data.sum, 1000000000)
        XCTAssertNil(data.labels["label_one"])
    }
    
    // MARK: - Test Concurrency
    
    func testConcurrency() throws {
        DispatchQueue.concurrentPerform(iterations: 5) { iteration in
            let counter = Counter(label: "my_counter")
            counter.increment()
        }
        
        meter.collect()
        
        let metric = testProcessor.metrics[0]
        let data = try XCTUnwrap(metric.data.last as? SumData<Int>)
        XCTAssertEqual(metric.name, "my_counter")
        XCTAssertEqual(metric.aggregationType, .intSum)
        XCTAssertEqual(data.sum, 5)
        XCTAssertNil(data.labels["label_one"])
    }

}
