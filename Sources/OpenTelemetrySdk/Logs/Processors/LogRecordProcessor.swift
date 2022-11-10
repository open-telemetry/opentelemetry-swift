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


}
