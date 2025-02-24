//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class NoopLogRecordProcessor: LogRecordProcessor {
  public static let noopLogRecordProcessor = NoopLogRecordProcessor()

  public func onEmit(logRecord: ReadableLogRecord) {}

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    .success
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    .success
  }
}
