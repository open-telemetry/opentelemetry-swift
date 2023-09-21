/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LogRecordProcessor {

    /// Called when a Logger's LogRecordBuilder emits a log record
    ///
    /// - Parameter logRecord: the log record emitted
    func onEmit(logRecord: ReadableLogRecord)

    /// Processes all span events that have not yet been processes
    ///
    /// - returns whether the task was successful
  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult
    
    /// Processes all span events that have not yet been processes anc closes used resources
    ///
    /// - returns whether the task was successful
  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult
}
