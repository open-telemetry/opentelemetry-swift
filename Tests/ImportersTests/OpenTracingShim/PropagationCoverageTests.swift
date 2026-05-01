/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTracingShim
import XCTest

final class PropagationCoverageTests: XCTestCase {
  func testExtractReturnsNilWhenContextInvalid() {
    let tracerProvider = TracerProviderSdk()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    OpenTelemetry.registerPropagators(textPropagators: [W3CTraceContextPropagator()],
                                      baggagePropagator: W3CBaggagePropagator())
    let baggage = DefaultBaggageManager.instance.baggageBuilder().build()
    OpenTelemetry.instance.contextProvider.setActiveBaggage(baggage)

    let telemetryInfo = TelemetryInfo(tracer: tracerProvider.get(instrumentationName: "p"),
                                      baggageManager: OpenTelemetry.instance.baggageManager,
                                      propagators: OpenTelemetry.instance.propagators)
    let propagation = Propagation(telemetryInfo: telemetryInfo)
    // Empty carrier → propagator returns nil/invalid.
    XCTAssertNil(propagation.extractTextFormat(carrier: [:]))
  }

  func testInjectTextFormatWritesEntries() {
    let tracerProvider = TracerProviderSdk()
    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    OpenTelemetry.registerPropagators(textPropagators: [W3CTraceContextPropagator()],
                                      baggagePropagator: W3CBaggagePropagator())
    let telemetryInfo = TelemetryInfo(tracer: tracerProvider.get(instrumentationName: "p"),
                                      baggageManager: OpenTelemetry.instance.baggageManager,
                                      propagators: OpenTelemetry.instance.propagators)
    let propagation = Propagation(telemetryInfo: telemetryInfo)

    let tracer = tracerProvider.get(instrumentationName: "p")
    let span = tracer.spanBuilder(spanName: "x").startSpan()
    defer { span.end() }
    let shim = SpanShim(telemetryInfo: telemetryInfo, span: span)
    let ctxShim = shim.context() as! SpanContextShim
    let carrier = NSMutableDictionary()
    propagation.injectTextFormat(contextShim: ctxShim, carrier: carrier)
    XCTAssertGreaterThan(carrier.count, 0)
    XCTAssertNotNil(carrier["traceparent"])
  }

  func testTextMapSetterStoresValue() {
    var carrier: [String: String] = [:]
    TextMapSetter().set(carrier: &carrier, key: "k", value: "v")
    XCTAssertEqual(carrier["k"], "v")
  }

  func testTextMapGetterReturnsExistingValue() {
    let getter = TextMapGetter()
    XCTAssertEqual(getter.get(carrier: ["k": "v"], key: "k"), ["v"])
    XCTAssertNil(getter.get(carrier: [:], key: "k"))
  }
}
