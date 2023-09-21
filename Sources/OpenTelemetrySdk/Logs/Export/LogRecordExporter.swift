/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LogRecordExporter {

  func export(logRecords: [ReadableLogRecord], explicitTimeout : TimeInterval?) -> ExportResult

    /// Shutdown the log exporter
    ///
  func shutdown(explicitTimeout: TimeInterval?)

    /// Processes all the log records that have not yet been processed
    ///
  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult
}
