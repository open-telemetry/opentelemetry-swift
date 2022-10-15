/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetrySdk
import XCTest

final class PushControllerTests: XCTestCase {
    fileprivate let lock = Lock()

    func testPushControllerCollectsAllMeters() {
        let controllerPushIntervalInSec = 0.025
        let collectionCountExpectedMin = 3
        let maxWaitInSec = (controllerPushIntervalInSec * Double(collectionCountExpectedMin)) + 2

        var exportCalledCount = 0
        let testExporter = TestMetricExporter(onExport: {
            self.lock.withLockVoid {
                exportCalledCount += 1
            }
        })
        let testProcessor = TestMetricProcessor()

        let meterProvider = MeterProviderSdk(metricProcessor: testProcessor,
                                             metricExporter: NoopMetricExporter())

        // Setup 2 meters whose Collect will increment the collect count.
        var meter1CollectCount = 0
        var meter2CollectCount = 0
        let meterSharedState = MeterSharedState(metricProcessor: testProcessor, metricPushInterval: controllerPushIntervalInSec, metricExporter: testExporter, resource: Resource())
        
        let meterInstrumentationScope1 = InstrumentationScopeInfo(name:"meter1")

        let  testMeter1 = TestMeter(meterSharedState: meterSharedState, instrumentationScopeInfo: meterInstrumentationScope1){
            self.lock.withLockVoid {
                meter1CollectCount += 1
            }
        }
        meterProvider.meterRegistry[meterInstrumentationScope1] = testMeter1

        
        let meterInstrumentationScope2 = InstrumentationScopeInfo(name: "meter2")
        let testMeter2 = TestMeter(meterSharedState:meterSharedState, instrumentationScopeInfo: meterInstrumentationScope2) {
            self.lock.withLockVoid {
                meter2CollectCount += 1
            }
        }
        meterProvider.meterRegistry[meterInstrumentationScope2] = testMeter2

        let pushInterval = controllerPushIntervalInSec

        let controller = PushMetricController(meterProvider: meterProvider, meterSharedState: meterSharedState)

        // Validate that collect is called on Meter1, Meter2.
        validateMeterCollect(meterCollectCount: &meter1CollectCount, expectedMeterCollectCount: collectionCountExpectedMin, meterName: "meter1", timeout: maxWaitInSec)
        validateMeterCollect(meterCollectCount: &meter2CollectCount, expectedMeterCollectCount: collectionCountExpectedMin, meterName: "meter2", timeout: maxWaitInSec)

        // Export must be called same no: of times as Collect.
        lock.withLockVoid {
            XCTAssertTrue(exportCalledCount >= collectionCountExpectedMin)
        }
        XCTAssertEqual(controller.meterSharedState.metricPushInterval, pushInterval)
    }

    func validateMeterCollect(meterCollectCount: inout Int, expectedMeterCollectCount: Int, meterName: String, timeout: TimeInterval) {
        // Sleep in short intervals, so the actual test duration is not always the max wait time.
        let start = Date()

        var wait = true
        lock.withLockVoid {
            if meterCollectCount >= expectedMeterCollectCount {
                wait = false
            }
        }

        while wait {
            lock.withLockVoid {
                if meterCollectCount >= expectedMeterCollectCount {
                    wait = false
                }
            }

            let elapsed = Date().timeIntervalSince(start)
            if elapsed <= timeout {
                usleep(1000000)
            } else {
                break
            }
        }

        lock.withLockVoid {
            XCTAssertGreaterThanOrEqual(meterCollectCount, expectedMeterCollectCount)
        }
    }
}
