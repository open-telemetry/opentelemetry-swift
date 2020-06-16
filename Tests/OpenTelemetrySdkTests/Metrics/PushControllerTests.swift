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

        let meterProvider = MeterSdkProvider(meterSharedState: MeterSharedState(metricProcessor: testProcessor))

        // Setup 2 meters whose Collect will increment the collect count.
        var meter1CollectCount = 0
        var meter2CollectCount = 0
        let testMeter1 = TestMeter(meterName: "meter1", metricProcessor: testProcessor) {
            self.lock.withLockVoid {
                meter1CollectCount += 1
            }
        }
        meterProvider.meterRegistry[MeterRegistryKey(name: "meter1")] = testMeter1

        let testMeter2 = TestMeter(meterName: "meter2", metricProcessor: testProcessor) {
            self.lock.withLockVoid {
                meter2CollectCount += 1
            }
        }
        meterProvider.meterRegistry[MeterRegistryKey(name: "meter2")] = testMeter2

        let pushInterval = controllerPushIntervalInSec

        _ = PushMetricController(meterProvider: meterProvider, metricProcessor: testProcessor, metricExporter: testExporter, pushInterval: pushInterval)

        // Validate that collect is called on Meter1, Meter2.
        validateMeterCollect(meterCollectCount: &meter1CollectCount, expectedMeterCollectCount: collectionCountExpectedMin, meterName: "meter1", timeout: maxWaitInSec)
        validateMeterCollect(meterCollectCount: &meter2CollectCount, expectedMeterCollectCount: collectionCountExpectedMin, meterName: "meter2", timeout: maxWaitInSec)

        // Export must be called same no: of times as Collect.
        lock.withLockVoid {
            XCTAssertTrue(exportCalledCount >= collectionCountExpectedMin)
        }
    }

    func validateMeterCollect(meterCollectCount: inout Int, expectedMeterCollectCount: Int, meterName: String, timeout: TimeInterval) {
        // Sleep in short intervals, so the actual test duration is not always the max wait time.
        let start = DispatchTime.now()

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

            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1000000000
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
