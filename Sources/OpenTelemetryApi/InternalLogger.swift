/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Logs what OpenTelemetry itself is doing, for developers debugging their setup. It doesn't
/// produce telemetry.
///
/// Messages go to `OpenTelemetry.instance.feedbackHandler`, or are printed if there isn't one. Only
/// errors are logged unless `OpenTelemetry.setDebugEnabled(true)` was called, in which case every
/// level is. A message that isn't logged is never built.
///
/// The handler is the app's code, so don't log while holding a lock it could need.
public enum InternalLogger {
  private enum Level: String {
    case debug
    case info
    case warn
    case error
  }

  public static func debug(_ message: @autoclosure () -> String) {
    log(.debug, message())
  }

  public static func info(_ message: @autoclosure () -> String) {
    log(.info, message())
  }

  public static func warn(_ message: @autoclosure () -> String) {
    log(.warn, message())
  }

  public static func error(_ message: @autoclosure () -> String) {
    log(.error, message())
  }

  private static func log(_ level: Level, _ message: @autoclosure () -> String) {
    guard level == .error || OpenTelemetry.instance.isDebugEnabled else { return }
    let line = "[\(level.rawValue)] \(message())"
    if let feedbackHandler = OpenTelemetry.instance.feedbackHandler {
      feedbackHandler(line)
    } else {
      print(line)
    }
  }
}
