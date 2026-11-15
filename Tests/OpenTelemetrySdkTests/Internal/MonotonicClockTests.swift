/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetrySdk
import XCTest

class MonotonicClockTests: XCTestCase {
  let epochNanos: UInt64 = 1_234_000_005_678
  var testClock: TestClock!

  override func setUp() {
    testClock = TestClock(nanos: Int64(epochNanos))
  }

  func testNanoTime() {
    XCTAssertEqual(testClock.now, TestUtils.dateFromNanos(Int64(epochNanos)))
    XCTAssertEqual(testClock.nanoTime, epochNanos)
    let monotonicClock = MonotonicClock(clock: testClock)
    testClock.advanceNanos(12345)
    XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
  }

  func testNow_PositiveIncrease() {
    let monotonicClock = MonotonicClock(clock: testClock)
    XCTAssertEqual(monotonicClock.nanoTime, testClock.nanoTime)
    testClock.advanceNanos(3_210)
    XCTAssertEqual(monotonicClock.nanoTime, 1_234_000_008_888)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_234_000_008_888).timeIntervalSinceReferenceDate)

    // Monotonic time continues increasing even when wall clock goes backwards
    testClock.advanceNanos(-2_210)
    XCTAssertEqual(monotonicClock.nanoTime, 1_234_000_011_098)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_234_000_011_098).timeIntervalSinceReferenceDate)

    testClock.advanceNanos(15_999_993_322)
    XCTAssertEqual(monotonicClock.nanoTime, 1_250_000_004_420)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_250_000_004_420).timeIntervalSinceReferenceDate)
  }

  func testNow_NegativeIncrease() {
    let monotonicClock = MonotonicClock(clock: testClock)
    XCTAssertEqual(monotonicClock.now, testClock.now)
    testClock.advanceNanos(-3_456)
    XCTAssertEqual(monotonicClock.nanoTime, 1_234_000_009_134)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_234_000_009_134).timeIntervalSinceReferenceDate)

    // Monotonic time continues increasing
    testClock.advanceNanos(2_456)
    XCTAssertEqual(monotonicClock.nanoTime, 1_234_000_011_590)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_234_000_011_590).timeIntervalSinceReferenceDate)

    testClock.advanceNanos(-14_000_004_678)
    XCTAssertEqual(monotonicClock.nanoTime, 1_248_000_016_268)
    XCTAssertEqual(monotonicClock.now.timeIntervalSinceReferenceDate,
                   TestUtils.dateFromNanos(1_248_000_016_268).timeIntervalSinceReferenceDate)
  }
}
