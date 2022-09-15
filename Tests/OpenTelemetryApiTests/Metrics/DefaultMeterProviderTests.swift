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
    func get(instrumentationName _: String, instrumentationVersion _: String?) -> Meter {
        return TestNoopMeter()
    }
}

class TestNoopMeter: Meter {
    func createRawDoubleHistogram(name: String) -> AnyRawHistogramMetric<Double> {
        return AnyRawHistogramMetric<Double>(NoopRawHistogramMetric<Double>())
    }
    
    func createRawIntHistogram(name: String) -> AnyRawHistogramMetric<Int> {
        return AnyRawHistogramMetric<Int>(NoopRawHistogramMetric<Int>())

    }
    
    func createRawDoubleCounter(name: String) -> AnyRawCounterMetric<Double> {
            return AnyRawCounterMetric<Double>(NoopRawCounterMetric<Double>())
    }
    
    func createRawIntCounter(name: String) -> AnyRawCounterMetric<Int> {
        return AnyRawCounterMetric<Int>(NoopRawCounterMetric<Int>())
    }
    
    func createIntCounter(name _: String, monotonic _: Bool) -> AnyCounterMetric<Int> {
        return AnyCounterMetric<Int>(NoopCounterMetric<Int>())
    }

    func createDoubleCounter(name _: String, monotonic _: Bool) -> AnyCounterMetric<Double> {
        return AnyCounterMetric<Double>(NoopCounterMetric<Double>())
    }

    func createIntMeasure(name _: String, absolute _: Bool) -> AnyMeasureMetric<Int> {
        return AnyMeasureMetric<Int>(NoopMeasureMetric<Int>())
    }

    func createDoubleMeasure(name _: String, absolute _: Bool) -> AnyMeasureMetric<Double> {
        return AnyMeasureMetric<Double>(NoopMeasureMetric<Double>())
    }
    
    func createIntHistogram(name: String, explicitBoundaries: Array<Int>? = nil, absolute: Bool) -> AnyHistogramMetric<Int> {
        return AnyHistogramMetric<Int>(NoopHistogramMetric<Int>())
    }
    
    func createDoubleHistogram(name: String, explicitBoundaries: Array<Double>? = nil, absolute: Bool) -> AnyHistogramMetric<Double> {
        return AnyHistogramMetric<Double>(NoopHistogramMetric<Double>())
    }

    func createIntObserver(name _: String, absolute _: Bool, callback _: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return NoopIntObserverMetric()
    }

    func createDoubleObserver(name _: String, absolute _: Bool, callback _: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return NoopDoubleObserverMetric()
    }

    func createIntObservableGauge(name _: String, callback _: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        return NoopIntObserverMetric()
    }

    func createDoubleObservableGauge(name _: String, callback _: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        return NoopDoubleObserverMetric()
    }

    func getLabelSet(labels _: [String: String]) -> LabelSet {
        return LabelSet.empty
    }
}
