/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class NoopLogRecordExporter: LogRecordExporter {
  public static let instance = NoopLogRecordExporter()

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> ExportResult {
    .success
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {}

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    .success
  }
}
