/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class InMemoryLogRecordExporter : LogRecordExporter {
  private var finishedLogRecords = [ReadableLogRecord]()
  private var isRunning = true
  
  public func getFinishedLogRecords() -> [ReadableLogRecord] {
    return finishedLogRecords
  }
  
  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> ExportResult {
    guard isRunning else {
      return .failure
    }
    finishedLogRecords.append(contentsOf: logRecords)
    return .success
  }
  
  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    finishedLogRecords.removeAll()
    isRunning = false
  }
  
  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    guard isRunning else {
      return .failure
    }
    return .success
  }
}
