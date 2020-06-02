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

final class MeterFactoryBaseTests: XCTestCase {
    override func setUp() {
        MeterFactoryBase.defaultFactory.reset()
    }

    func testDefault() {
        let defaultMeter = MeterFactoryBase.defaultFactory.getMeter(name: "")
        XCTAssert(defaultMeter is ProxyMeter)
        let otherMeter = MeterFactoryBase.defaultFactory.getMeter(name: "named meter")
        XCTAssert(otherMeter is ProxyMeter)
        XCTAssert(defaultMeter === otherMeter)

        let counter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Double>)
    }

    func testSetDefault() {
        let factory = TestMeter()
        MeterFactoryBase.setDefault(meterFactory: factory)
        XCTAssert(MeterFactoryBase.initialized)

        let defaultMeter = MeterFactoryBase.defaultFactory.getMeter(name: "")
        XCTAssert(defaultMeter is TestNoopMeter)

        let otherMeter = MeterFactoryBase.defaultFactory.getMeter(name: "named meter")
        XCTAssert(defaultMeter !== otherMeter)

        let counter = defaultMeter.createIntCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Int>)
    }

    func testSetDefaultTwice() {
        let factory = TestMeter()
        MeterFactoryBase.setDefault(meterFactory: factory)

        let factory2 = TestMeter()
        MeterFactoryBase.setDefault(meterFactory: factory2)

        XCTAssert(MeterFactoryBase.defaultFactory === factory)
    }

    func testUpdateDefault_CachedTracer() {
        let defaultMeter = MeterFactoryBase.defaultFactory.getMeter(name: "")
        let noOpCounter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(noOpCounter.internalCounter is NoopCounterMetric<Double>)

        MeterFactoryBase.setDefault(meterFactory: TestMeter())
        let counter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Double>)

        let newdefaultMeter = MeterFactoryBase.defaultFactory.getMeter(name: "")
        XCTAssert(defaultMeter !== newdefaultMeter)
    }
}

class TestMeter: MeterFactoryBase {
    override func getMeter(name: String, version: String? = nil) -> Meter {
        return TestNoopMeter()
    }
}

class TestNoopMeter: Meter {
    func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int> {
        return AnyCounterMetric<Int>(NoopCounterMetric<Int>())
    }

    func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double> {
        return AnyCounterMetric<Double>(NoopCounterMetric<Double>())
    }

    func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int> {
        return AnyMeasureMetric<Int>(NoopMeasureMetric<Int>())
    }

    func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double> {
        return AnyMeasureMetric<Double>(NoopMeasureMetric<Double>())
    }

    func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return NoopIntObserverMetric()
    }

    func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return NoopDoubleObserverMetric()
    }

    func getLabelSet(labels: [String: String]) -> LabelSet {
        return LabelSet.empty
    }
}
