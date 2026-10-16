/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LoggerProvider: AnyObject, Sendable {
  /// Returns a Logger for a given name and version
  /// - Parameters:
  ///     - instrumentationName: Name of the instrumentation library.
  ///     - Returns: a Logger instance
  func get(instrumentationScopeName: String) -> Logger

  /// Creates a LoggerBuilder for a named Logger instance
  ///
  /// - Parameter instrumentationScopeName: Name of the instrumentation library.
  /// - Returns: LoggerBuilder instance
  func loggerBuilder(instrumentationScopeName: String) -> LoggerBuilder
}
