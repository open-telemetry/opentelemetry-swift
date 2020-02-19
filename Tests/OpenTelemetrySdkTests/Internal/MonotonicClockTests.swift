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

class MonotonicClockTests: XCTestCase {
    let epochNanos: Int = 1234000005678
    var testClock: TestClock!

    override func setUp() {
        testClock = TestClock(nanos: epochNanos)
    }

    func testNanoTime() {
        XCTAssertEqual(testClock.now, epochNanos)
        let monotonicClock = MonotonicClock(clock: testClock)
        XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
        testClock.advanceNanos(12345)
        XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
    }

    func testNow_PositiveIncrease() {
        let monotonicClock = MonotonicClock(clock: testClock)
        XCTAssertEqual(monotonicClock.now, testClock.now)
        testClock.advanceNanos(3210)
        XCTAssertEqual(monotonicClock.now, 1234000008888)
        // Initial + 1000
        testClock.advanceNanos(-2210)
        XCTAssertEqual(monotonicClock.now, 1234000006678)
        testClock.advanceNanos(15999993322)
        XCTAssertEqual(monotonicClock.now, 1250000000000)
    }

    func testNow_NegativeIncrease() {
        let monotonicClock = MonotonicClock(clock: testClock)
        XCTAssertEqual(monotonicClock.now, testClock.now)
        testClock.advanceNanos(-3456)
        XCTAssertEqual(monotonicClock.now, 1234000002222)
        // Initial - 1000
        testClock.advanceNanos(2456)
        XCTAssertEqual(monotonicClock.now, 1234000004678)
        testClock.advanceNanos(-14000004678)
        XCTAssertEqual(monotonicClock.now, 1220000000000)
    }
}
