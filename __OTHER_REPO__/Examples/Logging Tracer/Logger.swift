/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class Logger {
  static let startTime = Date()

  static func printHeader() {
    print("TimeSinceStart | ThreadId | API")
  }

  static func log(_ s: String) {
    let output = String(format: "%.9f | %@ | %@", timeSinceStart(), Thread.current.description, s)
    print(output)
  }

  private static func timeSinceStart() -> Double {
    let start = startTime
    return Date().timeIntervalSince(start)
  }
}
