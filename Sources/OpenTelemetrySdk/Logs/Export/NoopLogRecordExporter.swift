/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class NoopLogRecordExporter : LogRecordExporter {
    public static let instance = NoopLogRecordExporter()

    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        .success
    }

    public func shutdown() {

    }

    public func forceFlush() -> ExportResult {
        .success
    }
}
