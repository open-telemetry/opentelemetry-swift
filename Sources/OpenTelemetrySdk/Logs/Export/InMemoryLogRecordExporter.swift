/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public final class InMemoryLogRecordExporter: LogRecordExporter {
  private let state = Locked(initialValue: State())

  private struct State {
    var finishedLogRecords = [ReadableLogRecord]()
    var isRunning = true
  }

  public func getFinishedLogRecords() -> [ReadableLogRecord] {
    state.locking { $0.finishedLogRecords }
  }

  public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> ExportResult {
    state.locking { state in
      guard state.isRunning else {
        return .failure
      }
      state.finishedLogRecords.append(contentsOf: logRecords)
      return .success
    }
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    state.locking { state in
      state.finishedLogRecords.removeAll()
      state.isRunning = false
    }
  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
    state.locking { state in
      guard state.isRunning else {
        return .failure
      }
      return .success
    }
  }
}
