/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class TestClockTests: XCTestCase {
  func testSetAndGetTime() {
    let clock = TestClock(nanos: 1234)
    XCTAssertEqual(clock.now, TestUtils.dateFromNanos(1234))
    clock.setTime(nanos: 9876543210)
    XCTAssertEqual(clock.now, TestUtils.dateFromNanos(9876543210))
  }

  func testAdvanceMillis() {
    let clock = TestClock(nanos: 1500000000)
    clock.advanceMillis(2600)
    XCTAssertEqual(clock.now, TestUtils.dateFromNanos(4100000000))
  }

  func testMeasureElapsedTime() {
    let clock = TestClock(nanos: 10000000000)
    let nanos1 = clock.nanoTime
    clock.setTime(nanos: 11000000000)
    let nanos2 = clock.nanoTime
    XCTAssertEqual(nanos2 - nanos1, 1000000000)
  }
}
