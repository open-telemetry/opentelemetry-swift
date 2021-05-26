/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

final class DefaultMeterProviderTests: XCTestCase {
    override func setUp() {
        DefaultMeterProvider.reset()
    }

    func testDefault() {
        let defaultMeter = DefaultMeterProvider.instance.get(instrumentationName: "", instrumentationVersion: nil)
        XCTAssert(defaultMeter is ProxyMeter)
        let otherMeter = DefaultMeterProvider.instance.get(instrumentationName: "named meter", instrumentationVersion: nil)
        XCTAssert(otherMeter is ProxyMeter)
        XCTAssert(defaultMeter is ProxyMeter)

        let counter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Double>)
    }

    func testSetDefault() {
        let factory = TestMeter()
        DefaultMeterProvider.setDefault(meterFactory: factory)
        XCTAssert(DefaultMeterProvider.initialized)

        let defaultMeter = DefaultMeterProvider.instance.get(instrumentationName: "", instrumentationVersion: nil)
        XCTAssert(defaultMeter is TestNoopMeter)

        let otherMeter = DefaultMeterProvider.instance.get(instrumentationName: "named meter", instrumentationVersion: nil)
        XCTAssert(otherMeter is TestNoopMeter)

        let counter = defaultMeter.createIntCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Int>)
    }

    func testSetDefaultTwice() {
        let factory = TestMeter()
        DefaultMeterProvider.setDefault(meterFactory: factory)

        let factory2 = TestMeter()
        DefaultMeterProvider.setDefault(meterFactory: factory2)

        XCTAssert(DefaultMeterProvider.instance === factory)
    }

    func testUpdateDefault_CachedTracer() {
        let defaultMeter = DefaultMeterProvider.instance.get(instrumentationName: "", instrumentationVersion: nil)
        let noOpCounter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(noOpCounter.internalCounter is NoopCounterMetric<Double>)

        DefaultMeterProvider.setDefault(meterFactory: TestMeter())
        let counter = defaultMeter.createDoubleCounter(name: "ctr")
        XCTAssert(counter.internalCounter is NoopCounterMetric<Double>)
    }
}

class TestMeter: MeterProvider {
    func get(instrumentationName: String, instrumentationVersion: String?) -> Meter {
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

    func createIntObservableGauge(name: String, callback: @escaping (IntObserverMetric) -> ()) -> IntObserverMetric {
        return NoopIntObserverMetric()
    }

    func createDoubleObservableGauge(name: String, callback: @escaping (DoubleObserverMetric) -> ()) -> DoubleObserverMetric {
        return NoopDoubleObserverMetric()
    }

    func getLabelSet(labels: [String: String]) -> LabelSet {
        return LabelSet.empty
    }
}
