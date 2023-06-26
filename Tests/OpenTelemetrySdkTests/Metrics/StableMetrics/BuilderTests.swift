//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class BuilderTests : XCTestCase {
  func testBuilders() {
    let meterProvider =  StableMeterProviderBuilder().build()
    let meter = meterProvider.meterBuilder(name: "meter").build()
    XCTAssertTrue(type(of:meter) == DefaultStableMeter.self)
    XCTAssertNotNil(meter.counterBuilder(name: "counter").ofDoubles().build())
    
    
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").buildWithCallback({ _ in }))
    XCTAssertNotNil(meter.gaugeBuilder(name: "gauge").ofLongs().buildWithCallback({ _ in }))
    XCTAssertNotNil(meter.histogramBuilder(name: "histogram").build())
    XCTAssertNotNil(meter.histogramBuilder(name: "histogram").ofLongs().build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").ofDoubles().build())
    XCTAssertNotNil(meter.upDownCounterBuilder(name: "updown").buildWithCallback({ _ in }))
  }
}
