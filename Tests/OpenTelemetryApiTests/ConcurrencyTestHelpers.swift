/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

extension XCTestCase {
  /// Waits for concurrently dispatched work to finish, failing the test on timeout.
  ///
  /// On timeout this drains the group (bounded) before returning: letting orphaned
  /// blocks keep running while later tests execute would attribute any crash or
  /// race they trigger to the wrong test.
  func waitForConcurrentWork(_ group: DispatchGroup,
                             timeout: TimeInterval = 30,
                             _ message: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
    if group.wait(timeout: .now() + timeout) == .timedOut {
      XCTFail("Timed out after \(timeout)s: \(message)", file: file, line: line)
      _ = group.wait(timeout: .now() + 120)
    }
  }
}
