//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

public class InstrumentSelectorTests: XCTestCase {
  func testDefault() {
    let defaultInstrumentSelector = InstrumentSelector.builder().build()
    XCTAssertNil(defaultInstrumentSelector.meterName)
    XCTAssertNil(defaultInstrumentSelector.instrumentType)
    XCTAssertNil(defaultInstrumentSelector.meterName)
    XCTAssertNil(defaultInstrumentSelector.meterVersion)
    XCTAssertNil(defaultInstrumentSelector.meterSchemaUrl)
    XCTAssertEqual(".*", defaultInstrumentSelector.instrumentName)
  }

  func testInstrumentSelector() {
    let basicInstrument = InstrumentSelector.builder().setInstrument(name: "instrument").build()
    XCTAssertEqual("instrument", basicInstrument.instrumentName)
    XCTAssertNil(basicInstrument.meterName)
    XCTAssertNil(basicInstrument.instrumentType)
    XCTAssertNil(basicInstrument.meterName)
    XCTAssertNil(basicInstrument.meterVersion)
    XCTAssertNil(basicInstrument.meterSchemaUrl)

    let fullSetSelector = InstrumentSelector.builder().setMeter(name: "MyMeter").setMeter(version: "1.0.0").setMeter(schemaUrl: "test.com").setInstrument(name: "instrument").setInstrument(type: .upDownCounter).build()

    XCTAssertEqual("MyMeter", fullSetSelector.meterName)
    XCTAssertEqual("1.0.0", fullSetSelector.meterVersion)
    XCTAssertEqual("test.com", fullSetSelector.meterSchemaUrl)
    XCTAssertEqual("instrument", fullSetSelector.instrumentName)
    XCTAssertEqual(InstrumentType.upDownCounter, fullSetSelector.instrumentType)
  }
}
