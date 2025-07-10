/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk

class AdvisoryParameterTests: XCTestCase {
    
  func testHistogramExportedDataUsesCustomBucketsWithWaitingExporter() {
    let waitingExporter = WaitingMetricExporter(numberToWaitFor: 1, aggregationTemporality: .delta)
    let stableMeterProvider = MeterProviderSdk.builder()
      .registerMetricReader(
        reader: PeriodicMetricReaderSdk(
          exporter: waitingExporter,
          exportInterval: 5.0
        )
      )
      .registerView(
        selector: InstrumentSelectorBuilder().build(),
        view: View.builder().build()
      )
      .build()
    
    let meter = stableMeterProvider.meterBuilder(name: "testMeter").build()
    
    let customBoundaries = [1.0, 5.0, 10.0, 25.0, 50.0, 100.0]
    
    let histogram = meter
      .histogramBuilder(name: "test_histogram_with_custom_buckets")
      .setExplicitBucketBoundariesAdvice(customBoundaries)
      .build()
    
    // Record some values to generate data
    histogram.record(value: 3.0)   // Should fall in bucket [1.0, 5.0)
    histogram.record(value: 7.0)   // Should fall in bucket [5.0, 10.0)
    histogram.record(value: 15.0)  // Should fall in bucket [10.0, 25.0)
    histogram.record(value: 75.0)  // Should fall in bucket [50.0, 100.0)
    histogram.record(value: 150.0) // Should fall in the overflow bucket (>100.0)
    
    // Wait for export using the waiting exporter
    let metrics = waitingExporter.waitForExport()
    
    // Verify that we received the expected metric
    XCTAssertEqual(metrics.count, 1)
    
    let metricData = metrics[0]
    XCTAssertEqual(metricData.name, "test_histogram_with_custom_buckets")
    XCTAssertEqual(metricData.type, .Histogram)
    
    // Get the histogram data and verify the boundaries
    let histogramData = metricData.getHistogramData()
    XCTAssertEqual(histogramData.count, 1)
    
    let pointData = histogramData[0]
    
    // Verify that the exported data uses our custom boundaries
    XCTAssertEqual(pointData.boundaries, customBoundaries)
    
    // Verify the bucket counts match our recorded values
    // Expected bucket counts: [0, 1, 1, 1, 0, 1, 1] 
    // (empty bucket <1.0, then 1 value in each: [1-5), [5-10), [10-25), empty [25-50), 1 in [50-100), 1 in overflow >100)
    let expectedCounts = [0, 1, 1, 1, 0, 1, 1]
    XCTAssertEqual(pointData.counts, expectedCounts)
    
    // Verify total count and sum
    XCTAssertEqual(pointData.count, 5)
    XCTAssertEqual(pointData.sum, 250.0) // 3 + 7 + 15 + 75 + 150
    
    // Verify min and max
    XCTAssertEqual(pointData.min, 3.0)
    XCTAssertEqual(pointData.max, 150.0)
  }
}
