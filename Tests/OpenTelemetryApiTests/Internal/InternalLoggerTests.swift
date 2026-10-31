/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
import XCTest

final class InternalLoggerTests: XCTestCase {
  private final class Lines: @unchecked Sendable {
    var values: [String] = []
  }

  private var lines: Lines!
  private var previousHandler: ((String) -> Void)?

  override func setUp() {
    super.setUp()
    let lines = Lines()
    self.lines = lines
    previousHandler = OpenTelemetry.instance.feedbackHandler
    OpenTelemetry.registerFeedbackHandler { lines.values.append($0) }
  }

  override func tearDown() {
    OpenTelemetry.setDebugEnabled(false)
    if let previousHandler {
      OpenTelemetry.registerFeedbackHandler(previousHandler)
    }
    super.tearDown()
  }

  private func logAllLevels() {
    InternalLogger.debug("one")
    InternalLogger.info("two")
    InternalLogger.warn("three")
    InternalLogger.error("four")
  }

  func testDebugModeIsOffByDefault() {
    XCTAssertFalse(OpenTelemetry.instance.isDebugEnabled)
  }

  func testOnlyErrorsAreLoggedWithoutDebugMode() {
    logAllLevels()

    XCTAssertEqual(lines.values, ["[error] four"])
  }

  func testEveryLevelIsLoggedInDebugMode() {
    OpenTelemetry.setDebugEnabled(true)

    logAllLevels()

    XCTAssertEqual(lines.values, ["[debug] one", "[info] two", "[warn] three", "[error] four"])
  }

  func testTurningDebugModeOffStopsLogging() {
    OpenTelemetry.setDebugEnabled(true)
    OpenTelemetry.setDebugEnabled(false)

    logAllLevels()

    XCTAssertEqual(lines.values, ["[error] four"])
  }

  func testMessageThatIsNotLoggedIsNotBuilt() {
    var wasBuilt = false
    func message() -> String {
      wasBuilt = true
      return "message"
    }

    InternalLogger.debug(message())
    InternalLogger.info(message())
    InternalLogger.warn(message())

    XCTAssertFalse(wasBuilt)
  }
}
