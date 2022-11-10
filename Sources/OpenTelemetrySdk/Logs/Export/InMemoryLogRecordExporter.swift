/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class InMemoryLogRecordExporter : LogRecordExporter {
    private var finishedLogRecords = [ReadableLogRecord]()
    private var isRunning = true

    public func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        guard isRunning else {
            return .failure
        }
        finishedLogRecords.append(contentsOf: logRecords)
        return .success
    }

    public func shutdown() {
        finishedLogRecords.removeAll()
        isRunning = false
    }

    public func forceFlush() -> ExportResult {
        guard isRunning else {
            return .failure
        }
        return .success
    }
}
