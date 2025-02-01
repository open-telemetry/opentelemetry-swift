//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import XCTest
@testable import OpenTelemetrySdk
import OpenTelemetryApi

class MockStableMetricExporter : StableMetricExporter {
  
  public var exportData : [StableMetricData] = [StableMetricData]()
  
  func export(metrics: [OpenTelemetrySdk.StableMetricData]) -> OpenTelemetrySdk.ExportResult {
      exportData = metrics
    return .success
  }
  
  func flush() -> OpenTelemetrySdk.ExportResult {
    .success
  }
  
  func shutdown() -> OpenTelemetrySdk.ExportResult {
    .success
  }
  
  func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
    .delta
  }
  
  
}

class StableMeterProviderTests : XCTestCase {
  func testStableMeterSdk() {
    let mockExporter = WaitingMetricExporter(numberToWaitFor: 3, aggregationTemporality: .delta)
    let stableMeterProvider = StableMeterProviderSdk.builder().registerMetricReader(reader: StablePeriodicMetricReaderSdk(exporter: mockExporter, exportInterval: 5.0)).registerView(selector: InstrumentSelectorBuilder().build(), view: StableView.builder().build()).build()
    let meterSdk = stableMeterProvider.meterBuilder(name: "myMeter").build()
    
    var counter = meterSdk.counterBuilder(name: "counter").build()
   
    var _ = meterSdk.gaugeBuilder(name: "observable_gauge").buildWithCallback { measurement in
      measurement.record(value: 1.0)
    }
    var histogram = meterSdk.histogramBuilder(name: "histogram").build()
    var upDown = meterSdk.upDownCounterBuilder(name: "upDown").build()

    var doubleGauge = meterSdk.gaugeBuilder(name: "double_gauge").build()
    doubleGauge.record(value: 5.0)

    var longGauge = meterSdk.gaugeBuilder(name: "long_gauge").ofLongs().build()
    longGauge.record(value: 10)

    counter.add(value: 1)
    histogram.record(value: 2.0)
    upDown.add(value: 100)
    
    let metrics = mockExporter.waitForExport()
    
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "counter" && (metric.data.points[0] as! LongPointData).value == 1
    }))
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "observable_gauge" && (metric.data.points[0] as! DoublePointData).value == 1.0
    }))
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "double_gauge" && (metric.data.points[0] as! DoublePointData).value == 5.0
    }))
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "long_gauge" && (metric.data.points[0] as! LongPointData).value == 10
    }))
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "histogram" && (metric.getHistogramData()[0].min == 2.0 && metric.getHistogramData()[0].max == 2.0)
    }))
    XCTAssertTrue(metrics.contains(where: { metric in
      metric.name == "upDown" && (metric.data.points[0] as! LongPointData).value == 100
    }))
  }
}
