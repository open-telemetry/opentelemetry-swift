/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class JaegerBaggagePropagatorTests: XCTestCase {
    let builder = DefaultBaggageBuilder()
    let jaegerPropagator = JaegerBaggagePropagator()
    let setter = TestSetter()
    let getter = TestGetter()

    func testInjectBaggage() {
        // Metadata won't be propagated, but it MUST NOT cause ay problem.
        let baggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value", metadata: "somemetadata; someother=foo")
            .build()

        var carrier = [String: String]()
        jaegerPropagator.inject(baggage: baggage, carrier: &carrier, setter: setter)

        let expected1 = [JaegerBaggagePropagator.baggagePrefix + "nometa": "nometa-value",
                         JaegerBaggagePropagator.baggagePrefix + "meta": "meta-value"]
        let expected2 = [JaegerBaggagePropagator.baggagePrefix + "meta": "meta-value",
                         JaegerBaggagePropagator.baggagePrefix + "nometa": "nometa-value"]
        XCTAssert(carrier == expected1 || carrier == expected2)
    }

    func testExtractBaggageWithPrefix() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggagePrefix + "nometa"] = "nometa-value"
        carrier[JaegerBaggagePropagator.baggagePrefix + "meta"] = "meta-value"
        carrier["another"] = "value"

        let expectedBaggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value")
            .build()

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertEqual(result?.getEntries().sorted(), expectedBaggage.getEntries().sorted())
    }

    func testExtractBaggageWithPrefixEmptyKey() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggagePrefix] = "value"

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)!
        XCTAssertTrue(result.getEntries().isEmpty)
    }

    func testExtractBaggageWithHeader() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggageHeader] = "nometa=nometa-value,meta=meta-value"

        let expectedBaggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value")
            .build()

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertEqual(result?.getEntries().sorted(), expectedBaggage.getEntries().sorted())
    }

    func testExtractBaggageWithHeaderAndSpaces() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggageHeader] = "nometa = nometa-value , meta = meta-value"

        let expectedBaggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value")
            .build()

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertEqual(result?.getEntries().sorted(), expectedBaggage.getEntries().sorted())
    }

    func testExtractBaggageWithHeaderInvalid() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggageHeader] = "nometa+novalue"

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertTrue(result?.getEntries().isEmpty ?? false)
    }

    func testExtractBaggageWithHeaderAndPrefix() {
        var carrier = [String: String]()
        carrier[JaegerBaggagePropagator.baggageHeader] = "nometa=nometa-value,meta=meta-value"
        carrier[JaegerBaggagePropagator.baggagePrefix + "foo"] = "bar"

        let expectedBaggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value")
            .put(key: "foo", value: "bar")
            .build()

        let result = jaegerPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertEqual(result?.getEntries().sorted(), expectedBaggage.getEntries().sorted())
    }
}
