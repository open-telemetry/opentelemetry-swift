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

class TestClockTests: XCTestCase {
    func testSetAndGetTime() {
        let clock = TestClock(nanos: 1234)
        XCTAssertEqual(clock.now, 1234)
        clock.setTime(nanos: 9876543210)
        XCTAssertEqual(clock.now, 9876543210)
    }

    func testAdvanceMillis() {
        let clock = TestClock(nanos: 1500000000)
        clock.advanceMillis(2600)
        XCTAssertEqual(clock.now, 4100000000)
    }

    func testMeasureElapsedTime() {
        let clock = TestClock(nanos: 10000000001)
        let nanos1 = clock.nanoTime
        clock.setTime(nanos: 11000000005)
        let nanos2 = clock.nanoTime
        XCTAssertEqual(nanos2 - nanos1, 1000000004)
    }
}
