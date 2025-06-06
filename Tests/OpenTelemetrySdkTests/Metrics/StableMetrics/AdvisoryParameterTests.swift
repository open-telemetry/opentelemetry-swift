/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
import OpenTelemetryApi
@testable import OpenTelemetrySdk

class AdvisoryParameterTests: XCTestCase {
  
  func testHistogramBuilderSetsAdvisoryParameters() {
    let mockExporter = MockStableMetricExporter()
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: mockExporter
    ).build()
    
    let stableMeterProvider = StableMeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()
    
    let meter = stableMeterProvider.meterBuilder(name: "testMeter").build()
    
    let customBoundaries = [1.0, 5.0, 10.0, 25.0, 50.0, 100.0]
    
    let doubleHistogram = meter
      .histogramBuilder(name: "test_double_histogram")
      .setExplicitBucketBoundariesAdvice(customBoundaries)
      .build()
    
    let longHistogram = meter
      .histogramBuilder(name: "test_long_histogram")
      .setExplicitBucketBoundariesAdvice(customBoundaries)
      .ofLongs()
      .build()
    
    XCTAssertEqual(doubleHistogram.instrumentDescriptor.explicitBucketBoundariesAdvice, customBoundaries)
    XCTAssertEqual(longHistogram.instrumentDescriptor.explicitBucketBoundariesAdvice, customBoundaries)
  }
  
  func testHistogramBuilderMethodChaining() {
    let mockExporter = MockStableMetricExporter()
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: mockExporter
    ).build()
    
    let stableMeterProvider = StableMeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()
    
    let meter = stableMeterProvider.meterBuilder(name: "testMeter").build()
    
    let customBoundaries = [0.5, 1.0, 2.0, 5.0]
    
    let histogram = meter
      .histogramBuilder(name: "test_histogram")
      .setDescription("Test histogram with advisory boundaries")
      .setUnit("ms")
      .setExplicitBucketBoundariesAdvice(customBoundaries)
      .build()
    
    XCTAssertEqual(histogram.instrumentDescriptor.name, "test_histogram")
    XCTAssertEqual(histogram.instrumentDescriptor.description, "Test histogram with advisory boundaries")
    XCTAssertEqual(histogram.instrumentDescriptor.unit, "ms")
    XCTAssertEqual(histogram.instrumentDescriptor.explicitBucketBoundariesAdvice, customBoundaries)
  }
  
  func testHistogramBuilderOfLongsPreservesAdvice() {
    let mockExporter = MockStableMetricExporter()
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: mockExporter
    ).build()
    
    let stableMeterProvider = StableMeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()
    
    let meter = stableMeterProvider.meterBuilder(name: "testMeter").build()
    
    let customBoundaries = [10.0, 100.0, 1000.0]
    
    let longHistogram = meter
      .histogramBuilder(name: "test_histogram")
      .setExplicitBucketBoundariesAdvice(customBoundaries)
      .setDescription("Test description")
      .setUnit("bytes")
      .ofLongs()
      .build()
    
    XCTAssertEqual(longHistogram.instrumentDescriptor.explicitBucketBoundariesAdvice, customBoundaries)
    XCTAssertEqual(longHistogram.instrumentDescriptor.description, "Test description")
    XCTAssertEqual(longHistogram.instrumentDescriptor.unit, "bytes")
    XCTAssertEqual(longHistogram.instrumentDescriptor.valueType, InstrumentValueType.long)
  }
  
  func testHistogramWithoutAdvisoryParameters() {
    let mockExporter = MockStableMetricExporter()
    let myReader = StablePeriodicMetricReaderBuilder(
      exporter: mockExporter
    ).build()
    
    let stableMeterProvider = StableMeterProviderSdk.builder()
      .registerMetricReader(reader: myReader)
      .registerView(
        selector: InstrumentSelector.builder().setMeter(name: "*").build(),
        view: StableView
          .builder().build()
      )
      .build()
    
    let meter = stableMeterProvider.meterBuilder(name: "testMeter").build()
    
    let histogram = meter
      .histogramBuilder(name: "test_histogram")
      .build()
    
    XCTAssertNil(histogram.instrumentDescriptor.explicitBucketBoundariesAdvice)
  }
}
