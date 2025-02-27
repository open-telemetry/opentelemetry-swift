/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class DataExportDelayTests: XCTestCase {
  private let mockPerformance = ExportPerformanceMock(initialExportDelay: 3,
                                                      defaultExportDelay: 5,
                                                      minExportDelay: 1,
                                                      maxExportDelay: 20,
                                                      exportDelayChangeRate: 0.1)

  func testWhenNotModified_itReturnsInitialDelay() {
    let delay = DataExportDelay(performance: mockPerformance)
    XCTAssertEqual(delay.current, mockPerformance.initialExportDelay)
    XCTAssertEqual(delay.current, mockPerformance.initialExportDelay)
  }

  func testWhenDecreasing_itGoesDownToMinimumDelay() {
    var delay = DataExportDelay(performance: mockPerformance)
    var previousValue: TimeInterval = delay.current

    while previousValue > mockPerformance.minExportDelay {
      delay.decrease()

      let nextValue = delay.current
      XCTAssertEqual(nextValue / previousValue,
                     1.0 - mockPerformance.exportDelayChangeRate,
                     accuracy: 0.1)
      XCTAssertLessThanOrEqual(nextValue, max(previousValue, mockPerformance.minExportDelay))

      previousValue = nextValue
    }
  }

  func testWhenIncreasing_itClampsToMaximumDelay() {
    var delay = DataExportDelay(performance: mockPerformance)
    var previousValue: TimeInterval = delay.current

    while previousValue < mockPerformance.maxExportDelay {
      delay.increase()

      let nextValue = delay.current
      XCTAssertEqual(nextValue / previousValue,
                     1.0 + mockPerformance.exportDelayChangeRate,
                     accuracy: 0.1)
      XCTAssertGreaterThanOrEqual(nextValue, min(previousValue, mockPerformance.maxExportDelay))
      previousValue = nextValue
    }
  }
}
