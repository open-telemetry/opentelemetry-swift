/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

/// Protocol for logging Faro transport operations
protocol FaroLogging {
  func log(_ message: String)
  func logError(_ message: String, error: Error?)
}

/// Default implementation of FaroLogging that prints to console
class FaroLogger: FaroLogging {
  func log(_ message: String) {
    print("[D]: \(message)")
  }

  func logError(_ message: String, error: Error?) {
    if let error {
      print("[E]: \(message): \(error)")
    } else {
      print("[E]: \(message)")
    }
  }
}

enum FaroLoggingFactory {
  private static var logger: FaroLogging = FaroLogger()

  static func getInstance() -> FaroLogging {
    return logger
  }

  static func setLogger(logger: FaroLogging) {
    self.logger = logger
  }
}
