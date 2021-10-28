/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class ZipkinBaggagePropagatorTests: XCTestCase {
    let builder = DefaultBaggageBuilder()
    let zipkinPropagator = ZipkinBaggagePropagator()
    let setter = TestSetter()
    let getter = TestGetter()

    func testInjectBaggage() {
        // Metadata won't be propagated, but it MUST NOT cause ay problem.
        let baggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value", metadata: "somemetadata; someother=foo")
            .build()

        var carrier = [String: String]()
        zipkinPropagator.inject(baggage: baggage, carrier: &carrier, setter: setter)

        let expected1 = [ZipkinBaggagePropagator.baggagePrefix + "nometa": "nometa-value",
                         ZipkinBaggagePropagator.baggagePrefix + "meta": "meta-value"]
        let expected2 = [ZipkinBaggagePropagator.baggagePrefix + "meta": "meta-value",
                         ZipkinBaggagePropagator.baggagePrefix + "nometa": "nometa-value"]
        XCTAssert(carrier == expected1 || carrier == expected2)
    }

    func testExtractBaggageWithPrefix() {
        var carrier = [String: String]()
        carrier[ZipkinBaggagePropagator.baggagePrefix + "nometa"] = "nometa-value"
        carrier[ZipkinBaggagePropagator.baggagePrefix + "meta"] = "meta-value"
        carrier["another"] = "value"

        let expectedBaggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value")
            .build()

        let result = zipkinPropagator.extract(carrier: carrier, getter: getter)
        XCTAssertEqual(result?.getEntries().sorted(), expectedBaggage.getEntries().sorted())
    }

    func testExtractBaggageWithPrefixEmptyKey() {
        var carrier = [String: String]()
        carrier[ZipkinBaggagePropagator.baggagePrefix] = "value"

        let result = zipkinPropagator.extract(carrier: carrier, getter: getter)!
        XCTAssertTrue(result.getEntries().isEmpty)
    }
}
