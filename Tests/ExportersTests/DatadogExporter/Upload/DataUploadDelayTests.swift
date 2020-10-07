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

@testable import DatadogExporter
import XCTest

class DataUploadDelayTests: XCTestCase {
    private let mockPerformance = UploadPerformanceMock(
        initialUploadDelay: 3,
        defaultUploadDelay: 5,
        minUploadDelay: 1,
        maxUploadDelay: 20,
        uploadDelayChangeRate: 0.1
    )

    func testWhenNotModified_itReturnsInitialDelay() {
        let delay = DataUploadDelay(performance: mockPerformance)
        XCTAssertEqual(delay.current, mockPerformance.initialUploadDelay)
        XCTAssertEqual(delay.current, mockPerformance.initialUploadDelay)
    }

    func testWhenDecreasing_itGoesDownToMinimumDelay() {
        var delay = DataUploadDelay(performance: mockPerformance)
        var previousValue: TimeInterval = delay.current

        while previousValue > mockPerformance.minUploadDelay {
            delay.decrease()

            let nextValue = delay.current
            XCTAssertEqual(
                nextValue / previousValue,
                1.0 - mockPerformance.uploadDelayChangeRate,
                accuracy: 0.1
            )
            XCTAssertLessThanOrEqual(nextValue, max(previousValue, mockPerformance.minUploadDelay))

            previousValue = nextValue
        }
    }

    func testWhenIncreasing_itClampsToMaximumDelay() {
        var delay = DataUploadDelay(performance: mockPerformance)
        var previousValue: TimeInterval = delay.current

        while previousValue < mockPerformance.maxUploadDelay {
            delay.increase()

            let nextValue = delay.current
            XCTAssertEqual(
                nextValue / previousValue,
                1.0 + mockPerformance.uploadDelayChangeRate,
                accuracy: 0.1
            )
            XCTAssertGreaterThanOrEqual(nextValue, min(previousValue, mockPerformance.maxUploadDelay))
            previousValue = nextValue
        }
    }
}
