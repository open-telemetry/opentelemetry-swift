// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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
