/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

final class CounterTests: XCTestCase {
    public func testIntCounterBoundInstrumentsStatusUpdatedCorrectlySingleThread() {
        let testProcessor = TestMetricProcessor()

        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        let testCounter = meter.createIntCounter(name: "testCounter").internalCounter as! CounterMetricSdk<Int>

        let labels1 = ["dim1": "value1"]
        let ls1 = meter.getLabelSet(labels: labels1)
        let labels2 = ["dim1": "value2"]
        let ls2 = meter.getLabelSet(labels: labels2)
        let labels3 = ["dim1": "value3"]
        let ls3 = meter.getLabelSet(labels: labels3)

        // We have ls1, ls2, ls3
        // ls1 and ls3 are not bound so they should removed when no usage for a Collect cycle.
        // ls2 is bound by user.
        testCounter.add(value: 100, labelset: ls1)
        testCounter.add(value: 10, labelset: ls1)
        // initial status for temp bound instruments are UpdatePending.
        XCTAssertEqual(RecordStatus.updatePending, testCounter.boundInstruments[ls1]?.status)

        let boundCounterLabel2 = testCounter.bind(labelset: ls2)
        boundCounterLabel2.add(value: 200)
        // initial/forever status for user bound instruments are Bound.
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        testCounter.add(value: 200, labelset: ls3)
        testCounter.add(value: 10, labelset: ls3)
        // initial status for temp bound instruments are UpdatePending.
        XCTAssertEqual(RecordStatus.updatePending, testCounter.boundInstruments[ls3]?.status)

        // This collect should mark ls1, ls3 as noPendingUpdate, leave ls2 untouched.
        meter.collect()

        // Validate collect() has marked records correctly.
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls3]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        // Use ls1 again, so that it'll be promoted to UpdatePending
        testCounter.add(value: 100, labelset: ls1)

        // This collect should mark ls1 as noPendingUpdate, leave ls2 untouched.
        // And ls3 as candidateForRemoval, as it was not used since last Collect
        meter.collect()

        // Validate collect() has marked records correctly.
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls3]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        // This collect should mark
        // ls1 as candidateForRemoval as it was not used since last Collect
        // leave ls2 untouched.
        // ls3 should be physically removed as it remained candidateForRemoval during an entire Collect cycle.
        meter.collect()
        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)
        XCTAssertNil(testCounter.boundInstruments[ls3])
    }

    public func testDoubleCounterBoundInstrumentsStatusUpdatedCorrectlySingleThread() {
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        let testCounter = meter.createDoubleCounter(name: "testCounter").internalCounter as! CounterMetricSdk<Double>

        let labels1 = ["dim1": "value1"]
        let ls1 = meter.getLabelSet(labels: labels1)
        let labels2 = ["dim1": "value2"]
        let ls2 = meter.getLabelSet(labels: labels2)
        let labels3 = ["dim1": "value3"]
        let ls3 = meter.getLabelSet(labels: labels3)

        // We have ls1, ls2, ls3
        // ls1 and ls3 are not bound so they should removed when no usage for a Collect cycle.
        // ls2 is bound by user.
        testCounter.add(value: 100.0, labelset: ls1)
        testCounter.add(value: 10.0, labelset: ls1)
        // initial status for temp bound instruments are UpdatePending.
        XCTAssertEqual(RecordStatus.updatePending, testCounter.boundInstruments[ls1]?.status)

        let boundCounterLabel2 = testCounter.bind(labelset: ls2)
        boundCounterLabel2.add(value: 200.0)
        // initial/forever status for user bound instruments are Bound.
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        testCounter.add(value: 200.0, labelset: ls3)
        testCounter.add(value: 10.0, labelset: ls3)
        // initial status for temp bound instruments are UpdatePending.
        XCTAssertEqual(RecordStatus.updatePending, testCounter.boundInstruments[ls3]?.status)

        // This collect should mark ls1, ls3 as noPendingUpdate, leave ls2 untouched.
        meter.collect()

        // Validate collect() has marked records correctly.
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls3]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        // Use ls1 again, so that it'll be promoted to UpdatePending
        testCounter.add(value: 100.0, labelset: ls1)

        // This collect should mark ls1 as noPendingUpdate, leave ls2 untouched.
        // And ls3 as candidateForRemoval, as it was not used since last Collect
        meter.collect()

        // Validate collect() has marked records correctly.
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls3]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)

        // This collect should mark
        // ls1 as candidateForRemoval as it was not used since last Collect
        // leave ls2 untouched.
        // ls3 should be physically removed as it remained candidateForRemoval during an entire Collect cycle.
        meter.collect()
        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls1]?.status)
        XCTAssertEqual(RecordStatus.bound, testCounter.boundInstruments[ls2]?.status)
        XCTAssertNil(testCounter.boundInstruments[ls3])
    }

    public func testIntCounterBoundInstrumentsStatusUpdatedCorrectlyMultiThread() throws {
        #if os(watchOS)
        throw XCTSkip("Test is flaky on watchOS")
        #else
        let testProcessor = TestMetricProcessor()
        let meter = MeterProviderSdk(metricProcessor: testProcessor, metricExporter: NoopMetricExporter()).get(instrumentationName: "scope1") as! MeterSdk
        let testCounter = meter.createIntCounter(name: "testCounter").internalCounter as! CounterMetricSdk<Int>

        let labels1 = ["dim1": "value1"]
        let ls1 = meter.getLabelSet(labels: labels1)

        // Call metric update with ls1 so that ls1 wont be brand new labelset when doing multi-thread test.
        testCounter.add(value: 100, labelset: ls1)
        testCounter.add(value: 10, labelset: ls1)

        // This collect should mark ls1 NoPendingUpdate
        meter.collect()

        // Validate collect() has marked records correctly.
        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)

        // Another collect(). This collect should mark ls1 as CandidateForRemoval.
        meter.collect()
        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls1]?.status)

        let mygroup = DispatchGroup()
        DispatchQueue.global().async(group: mygroup) {
            for _ in 0 ..< 5 {
                meter.collect()
            }
        }
        DispatchQueue.global().async(group: mygroup) {
            for _ in 0 ..< 5 {
                testCounter.add(value: 100, labelset: ls1)
            }
        }
        mygroup.wait()

        // Validate that the exported record doesn't miss any update.
        // The Add(100) value must have already been exported, or must be exported in the next Collect().
        meter.collect()
        var sum = 0
        testProcessor.metrics.forEach {
            $0.data.forEach {
                sum += ($0 as! SumData<Int>).sum
            }
        }
        // 610 = 110 from initial update, 500 from the multi-thread test case.
        XCTAssertEqual(610, sum)
        #endif
    }

    public func testDoubleCounterBoundInstrumentsStatusUpdatedCorrectlyMultiThread() {
//        let testProcessor = TestMetricProcessor()
//        let meterSharedState = MeterSharedState(metricProcessor: testProcessor)
//        let meter = MeterProviderSdk(meterSharedState: meterSharedState).get(instrumentationName: "scope1") as! MeterSdk
//        let testCounter = meter.createDoubleCounter(name: "testCounter").internalCounter as! CounterMetricSdk<Double>
//
//        let labels1 = ["dim1": "value1"]
//        let ls1 = meter.getLabelSet(labels: labels1)
//
//        // Call metric update with ls1 so that ls1 wont be brand new labelset when doing multi-thread test.
//        testCounter.add(  value: 100.0, labelset: ls1)
//        testCounter.add(  value: 10.0, labelset: ls1)
//
//        // This collect should mark ls1 NoPendingUpdate
//        meter.collect()
//
//        // Validate collect() has marked records correctly.
//        XCTAssertEqual(RecordStatus.noPendingUpdate, testCounter.boundInstruments[ls1]?.status)
//
//        // Another collect(). This collect should mark ls1 as CandidateForRemoval.
//        meter.collect()
//        XCTAssertEqual(RecordStatus.candidateForRemoval, testCounter.boundInstruments[ls1]?.status)
//
//        let mygroup = DispatchGroup()
//        DispatchQueue.global().async(group: mygroup) {
//            for _ in 0 ..< 5 {
//                meter.collect()
//            }
//        }
//        DispatchQueue.global().async(group: mygroup) {
//            for _ in 0 ..< 5 {
//                testCounter.add(  value: 100.0, labelset: ls1)
//            }
//        }
//        mygroup.wait()
//
//        // Validate that the exported record doesn't miss any update.
//        // The Add(100) value must have already been exported, or must be exported in the next Collect().
//        meter.collect()
//        var sum = 0.0
//        testProcessor.metrics.forEach {
//            $0.data.forEach {
//                sum += ($0 as! SumData<Double>).sum
//            }
//        }
//        // 610 = 110 from initial update, 500 from the multi-thread test case.
//        XCTAssertEqual(610.0, sum)
    }
}
