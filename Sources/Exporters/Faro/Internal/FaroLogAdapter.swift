/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adapter to convert OpenTelemetry log records to Faro log format
class FaroLogAdapter {
  /// Static date provider for timestamp handling
  static var dateProvider: DateProviding = DateProvider()

  /// Convert an array of OpenTelemetry log records to Faro logs
  /// - Parameter logRecords: The OTel log records to convert
  /// - Returns: An array of FaroLog objects
  static func toFaroLogs(logRecords: [ReadableLogRecord]) -> [FaroLog] {
    return logRecords.map { toFaroLog(logRecord: $0) }
  }

  /// Convert a single OpenTelemetry log record to a Faro log
  /// - Parameter logRecord: The OTel log record to convert
  /// - Returns: A FaroLog object
  private static func toFaroLog(logRecord: ReadableLogRecord) -> FaroLog {
    // Convert timestamp to ISO8601 string (required by Faro)
    let dateTimestamp = logRecord.timestamp
    let timestamp = dateProvider.iso8601String(from: logRecord.timestamp)

    // Convert severity to Faro log level
    let level = convertSeverityToLogLevel(severity: logRecord.severity)

    // Get message from body attribute or fallback to empty string
    let message: String = if let body = logRecord.body {
      body.description
    } else {
      ""
    }

    // Convert attributes to Faro context
    var context = [String: String]()
    for (key, value) in logRecord.attributes {
      context[key] = value.description
    }

    // Add trace context if available
    let traceContext: FaroTraceContext?
    if let spanContext = logRecord.spanContext {
      let traceId = spanContext.traceId.hexString
      let spanId = spanContext.spanId.hexString
      traceContext = FaroTraceContext.create(traceId: traceId, spanId: spanId)
    } else {
      traceContext = nil
    }

    return FaroLog(
      timestamp: timestamp,
      dateTimestamp: dateTimestamp,
      level: level,
      message: message,
      context: context.isEmpty ? nil : context,
      trace: traceContext
    )
  }

  /// Convert OTel severity to Faro log level
  /// - Parameter severity: The OTel severity
  /// - Returns: The corresponding Faro log level
  private static func convertSeverityToLogLevel(severity: Severity?) -> FaroLogLevel {
    guard let severity else {
      return .info // Default to info level if no severity provided
    }

    switch severity {
    case .trace, .trace2, .trace3, .trace4:
      return .trace
    case .debug, .debug2, .debug3, .debug4:
      return .debug
    case .info, .info2, .info3, .info4:
      return .info
    case .warn, .warn2, .warn3, .warn4:
      return .warning
    case .error, .error2, .error3, .error4:
      return .error
    case .fatal, .fatal2, .fatal3, .fatal4:
      return .error // Faro doesn't have a fatal level, using error as closest match
    }
  }
}
