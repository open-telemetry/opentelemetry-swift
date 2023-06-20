//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

@testable import OpenTelemetrySdk
import XCTest

class BuilderTests : XCTestCase {
  func testBuilders() {
    let meterProvider =  StableMeterProviderBuilder().build()
    let meter = meterProvider.meterBuilder(name: "meter").build()
    let counter = meter.counterBuilder(name: "counter").ofDoubles().build()
    XCTAssertTrue(type(of: counter) == DoubleCounterSdk.self)
    
    XCTAssertTrue(type(of: meter.counterBuilder(name: "counter").build()) == LongCounterSdk.self)
    
    XCTAssertTrue(type(of:meter.gaugeBuilder(name: "gauge").buildWithCallback({ _ in })) == ObservableInstrumentSdk.self)
    XCTAssertTrue(type(of:meter.gaugeBuilder(name: "gauge").ofLongs().buildWithCallback({ _ in })) == ObservableInstrumentSdk.self)
    XCTAssertTrue(type(of: meter.histogramBuilder(name: "histogram").build()) == DoubleHistogramMeterSdk.self)
    XCTAssertTrue(type(of: meter.histogramBuilder(name: "histogram").ofLongs().build()) == LongHistogramMeterSdk.self)
    XCTAssertTrue(type(of:meter.upDownCounterBuilder(name: "updown").build()) == LongUpDownCounterSdk.self)
    XCTAssertTrue(type(of:meter.upDownCounterBuilder(name: "updown").ofDoubles().build()) == DoubleUpDownCounterSdk.self)
    XCTAssertTrue(type(of:meter.upDownCounterBuilder(name: "updown").buildWithCallback({ _ in })) == ObservableInstrumentSdk.self)
  }
}
