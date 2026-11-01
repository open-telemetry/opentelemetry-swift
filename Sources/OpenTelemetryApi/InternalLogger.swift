/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(Darwin)
  import os
#endif

/// Logs what OpenTelemetry itself is doing, for developers debugging their setup. It doesn't
/// produce telemetry.
///
/// Every line names the module it came from, read from the caller's `#fileID`, so a message
/// doesn't repeat it: `[warn] MincoreLaunchInstrumentation: couldn't sample the launch's pages.`
///
/// Messages go to `OpenTelemetry.instance.feedbackHandler`. Without one they go to the unified log
/// on Apple platforms, under the `io.opentelemetry.swift` subsystem with the module as the
/// category, so `log stream` and Console can filter them, and to `print` on platforms that have no
/// unified log. Only errors are logged unless `OpenTelemetry.setDebugEnabled(true)` was called, in
/// which case every level is. A message that isn't logged is never built.
///
/// The handler is the app's code, so don't log while holding a lock it could need.
public enum InternalLogger {
  private enum Level: String {
    case debug
    case info
    case warn
    case error
  }

  public static func debug(_ message: @autoclosure () -> String, fileID: StaticString = #fileID) {
    log(.debug, message(), fileID: fileID)
  }

  public static func info(_ message: @autoclosure () -> String, fileID: StaticString = #fileID) {
    log(.info, message(), fileID: fileID)
  }

  public static func warn(_ message: @autoclosure () -> String, fileID: StaticString = #fileID) {
    log(.warn, message(), fileID: fileID)
  }

  public static func error(_ message: @autoclosure () -> String, fileID: StaticString = #fileID) {
    log(.error, message(), fileID: fileID)
  }

  private static func log(_ level: Level, _ message: @autoclosure () -> String, fileID: StaticString) {
    guard level == .error || OpenTelemetry.instance.isDebugEnabled else { return }
    let module = moduleName(fileID)
    let text = message()
    if let feedbackHandler = OpenTelemetry.instance.feedbackHandler {
      feedbackHandler("[\(level.rawValue)] \(module): \(text)")
      return
    }
    #if canImport(Darwin)
      // The unified log records the level and the category itself, so the message repeats neither.
      // These messages describe what the SDK did and hold no data of the user's, so they're logged
      // publicly; without that they'd read as `<private>` outside the process.
      // Qualified, because this module exports a `Logger` protocol of its own for the logs API.
      let logger = os.Logger(subsystem: "io.opentelemetry.swift", category: module)
      switch level {
      case .debug: logger.debug("\(text, privacy: .public)")
      case .info: logger.info("\(text, privacy: .public)")
      case .warn: logger.warning("\(text, privacy: .public)")
      case .error: logger.error("\(text, privacy: .public)")
      }
    #else
      print("[\(level.rawValue)] \(module): \(text)")
    #endif
  }

  /// The module the caller's `#fileID` starts with, which is the target the message came from.
  private static func moduleName(_ fileID: StaticString) -> String {
    let fileID = fileID.description
    guard let separator = fileID.firstIndex(of: "/") else { return fileID }
    return String(fileID[..<separator])
  }
}
