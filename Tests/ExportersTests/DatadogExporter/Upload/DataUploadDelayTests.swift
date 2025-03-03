/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class DataUploadDelayTests: XCTestCase {
  private let mockPerformance = UploadPerformanceMock(initialUploadDelay: 3,
                                                      defaultUploadDelay: 5,
                                                      minUploadDelay: 1,
                                                      maxUploadDelay: 20,
                                                      uploadDelayChangeRate: 0.1)

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
      XCTAssertEqual(nextValue / previousValue,
                     1.0 - mockPerformance.uploadDelayChangeRate,
                     accuracy: 0.1)
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
      XCTAssertEqual(nextValue / previousValue,
                     1.0 + mockPerformance.uploadDelayChangeRate,
                     accuracy: 0.1)
      XCTAssertGreaterThanOrEqual(nextValue, min(previousValue, mockPerformance.maxUploadDelay))
      previousValue = nextValue
    }
  }
}
