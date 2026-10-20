/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LogRecordExporter: Sendable {
  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult

  /// Shutdown the log exporter
  ///
  func shutdown(explicitTimeout: TimeInterval?)

  /// Processes all the log records that have not yet been processed
  ///
  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) async -> ExportResult

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func shutdown(explicitTimeout: TimeInterval?) async

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func forceFlush(explicitTimeout: TimeInterval?) async -> ExportResult
}

public extension LogRecordExporter {
  func export(logRecords: [ReadableLogRecord]) -> ExportResult {
    return export(logRecords: logRecords, explicitTimeout: nil)
  }

  func shutdown() {
    shutdown(explicitTimeout: nil)
  }

  func forceFlush() -> ExportResult {
    return forceFlush(explicitTimeout: nil)
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension LogRecordExporter {
  func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) async -> ExportResult {
    assertionFailure("async export(logRecords:explicitTimeout:) must be implemented by \(type(of: self))")
    return .failure
  }

  func shutdown(explicitTimeout: TimeInterval?) async {
    assertionFailure("async shutdown(explicitTimeout:) must be implemented by \(type(of: self))")
  }

  func forceFlush(explicitTimeout: TimeInterval?) async -> ExportResult {
    assertionFailure("async forceFlush(explicitTimeout:) must be implemented by \(type(of: self))")
    return .failure
  }

  func export(logRecords: [ReadableLogRecord]) async -> ExportResult {
    return await export(logRecords: logRecords, explicitTimeout: nil)
  }

  func shutdown() async {
    await shutdown(explicitTimeout: nil)
  }

  func forceFlush() async -> ExportResult {
    return await forceFlush(explicitTimeout: nil)
  }
}
