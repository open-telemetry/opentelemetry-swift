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

class W3BaggagePropagatorTest: XCTestCase {
    struct TestSetter: Setter {
        func set(carrier: inout [String: String], key: String, value: String) {
            carrier[key] = value
        }
    }

    struct TestGetter: Getter {
        func get(carrier: [String: String], key: String) -> [String]? {
            if let value = carrier[key] {
                return [value]
            }
            return nil
        }
    }

    let setter = TestSetter()
    let getter = TestGetter()
    let propagator = W3CBaggagePropagator()
    let builder = DefaultBaggageBuilder()

    override func setUp() {}

    func testFields() {
        XCTAssertEqual(propagator.fields.count, 1)
        XCTAssertTrue(propagator.fields.contains("baggage"))
    }

    func testxtractNoBaggageHeader() {
        let result = propagator.extract(carrier: [:], getter: getter)
        XCTAssertNil(result)
    }

    func testExtractEmptyBaggageHeader() {
        let result = propagator.extract(carrier: ["baggage": ""], getter: getter)!
        XCTAssert(result == EmptyBaggage.instance)
    }

    func testExtractSingleEntry() {
        let result = propagator.extract(carrier: ["baggage": "key=value"], getter: getter)!
        let expectedBaggage = builder.put(key: "key", value: "value").build()
        XCTAssert(result == expectedBaggage)
    }

    func testExtractMultiEntry() {
        let result = propagator.extract(carrier: ["baggage": "key1=value1,key2=value2"], getter: getter)!
        let expectedBaggage = builder.put(key: "key1", value: "value1").put(key: "key2", value: "value2").build()
        XCTAssert(result == expectedBaggage)
    }

    func testExtractDuplicateKeys() {
        let result = propagator.extract(carrier: ["baggage": "key=value1,key=value2"], getter: getter)!
        let expectedBaggage = builder.put(key: "key", value: "value2").build()
        XCTAssert(result == expectedBaggage)
    }

    func testExtractWithMetadata() {
        let result = propagator.extract(carrier: ["baggage": "key=value;metadata-key=value;othermetadata"], getter: getter)!
        let expectedBaggage = builder.put(key: "key", value: "value", metadata: "metadata-key=value;othermetadata")
            .build()
        XCTAssert(result == expectedBaggage)
    }

    func testExtractFullComplexities() {
        let result = propagator.extract(carrier: ["baggage": "key1= value1; metadata-key = value; othermetadata, " +
                                                    "key2 =value2 , key3 =\tvalue3 ; "], getter: getter)!
        let expectedBaggage = builder.put(key: "key1", value: "value1", metadata: "metadata-key = value; othermetadata")
            .put(key: "key2", value: "value2")
            .put(key: "key3", value: "value3")
            .build()
        XCTAssert(result == expectedBaggage)
    }

    func testInjectEmptyBaggage() {
        var carrier = [String: String]()
        propagator.inject(baggage: EmptyBaggage.instance, carrier: &carrier, setter: setter)
        XCTAssertEqual(carrier.count, 0)
    }

    func testInject() {
        let baggage = builder.put(key: "nometa", value: "nometa-value")
            .put(key: "nometa", value: "nometa-value")
            .put(key: "meta", value: "meta-value", metadata: "somemetadata; someother=foo")
            .build()

        var carrier = [String: String]()
        propagator.inject(baggage: baggage, carrier: &carrier, setter: setter)

        let expected1 = ["baggage": "meta=meta-value;somemetadata; someother=foo,nometa=nometa-value"]
        let expected2 = ["baggage": "nometa=nometa-value,meta=meta-value;somemetadata; someother=foo"]
        XCTAssert( carrier == expected1 || carrier == expected2)
    }
}
