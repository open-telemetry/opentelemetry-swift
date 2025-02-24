/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import OpenTelemetrySdk
import Opentracing
@testable import OpenTracingShim
import XCTest

class TraceShimTests: XCTestCase {
  func testCreateTracerShimDefault() {
    let tracerShim = TraceShim.createTracerShim() as! TracerShim
    XCTAssert(OpenTelemetry.instance.tracerProvider.get(instrumentationName: "opentracingshim", instrumentationVersion: nil) === tracerShim.tracer)
    XCTAssert(OpenTelemetry.instance.baggageManager === tracerShim.baggageManager)
  }

  func testCreateTracerShim() {
    let sdk = OpenTelemetry.instance.tracerProvider
    let baggageManager = DefaultBaggageManager.instance
    let tracerShim = TraceShim.createTracerShim(tracerProvider: sdk, baggageManager: baggageManager) as! TracerShim

    XCTAssert(sdk.get(instrumentationName: "opentracingshim", instrumentationVersion: nil) === tracerShim.tracer)
    XCTAssert(baggageManager === tracerShim.baggageManager)
  }
}
