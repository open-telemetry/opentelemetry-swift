//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

final class LogRecordExporterMock: LogRecordExporter {
  private let state = Locked(initialValue: State())

  struct State {
    var exportCalledTimes: Int = 0
    var exportCalledData: [ReadableLogRecord]?
    var shutdownCalledTimes: Int = 0
    var forceFlushCalledTimes: Int = 0
    var returnValue: ExportResult = .success
  }

  var exportCalledTimes: Int {
    get { state.locking { $0.exportCalledTimes } }
    set { state.locking { $0.exportCalledTimes = newValue } }
  }

  var exportCalledData: [ReadableLogRecord]? {
    get { state.locking { $0.exportCalledData } }
    set { state.locking { $0.exportCalledData = newValue } }
  }

  var shutdownCalledTimes: Int {
    get { state.locking { $0.shutdownCalledTimes } }
    set { state.locking { $0.shutdownCalledTimes = newValue } }
  }

  var forceFlushCalledTimes: Int {
    get { state.locking { $0.forceFlushCalledTimes } }
    set { state.locking { $0.forceFlushCalledTimes = newValue } }
  }

  var returnValue: ExportResult {
    get { state.locking { $0.returnValue } }
    set { state.locking { $0.returnValue = newValue } }
  }

  func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    state.locking { state in
      state.exportCalledTimes += 1
      state.exportCalledData = logRecords
      return state.returnValue
    }
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    state.locking { $0.shutdownCalledTimes += 1 }
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    state.locking { state in
      state.forceFlushCalledTimes += 1
      return state.returnValue
    }
  }
}
