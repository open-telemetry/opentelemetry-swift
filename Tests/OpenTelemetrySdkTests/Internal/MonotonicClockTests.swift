/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class MonotonicClockTests: XCTestCase {
  let epochNanos: UInt64 = 1234000005678
  var testClock: TestClock!

  override func setUp() {
    testClock = TestClock(nanos: epochNanos)
  }

  func testNanoTime() {
    XCTAssertEqual(testClock.now, TestUtils.dateFromNanos(epochNanos))
    let monotonicClock = MonotonicClock(clock: testClock)
    XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
    testClock.advanceNanos(12345)
    XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
  }

  func testNow_PositiveIncrease() {
    let monotonicClock = MonotonicClock(clock: testClock)
    XCTAssertEqual(monotonicClock.now, testClock.now)
    testClock.advanceNanos(3210)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1234000008888))
    // Initial + 1000
    testClock.advanceNanos(-2210)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1234000006678))
    testClock.advanceNanos(15999993322)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1250000000000))
  }

  func testNow_NegativeIncrease() {
    let monotonicClock = MonotonicClock(clock: testClock)
    XCTAssertEqual(monotonicClock.now, testClock.now)
    testClock.advanceNanos(-3456)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1234000002222))
    // Initial - 1000
    testClock.advanceNanos(2456)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1234000004678))
    testClock.advanceNanos(-14000004678)
    XCTAssertEqual(monotonicClock.now, TestUtils.dateFromNanos(1220000000000))
  }
}
