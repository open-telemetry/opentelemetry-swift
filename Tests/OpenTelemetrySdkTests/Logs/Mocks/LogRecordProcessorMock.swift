//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetrySdk

class LogRecordProcessorMock: LogRecordProcessor {
  var onEmitCalledTimes = 0
  lazy var onEmitCalled: Bool = self.onEmitCalledTimes > 0
  var onEmitCalledLogRecord: ReadableLogRecord?

  var forceFlushCalledTimes = 0
  lazy var forceFlushCalled: Bool = self.forceFlushCalledTimes > 0

  var shutdownCalledTimes = 0
  lazy var shutdownCalled: Bool = self.shutdownCalledTimes > 0

  func onEmit(logRecord: OpenTelemetrySdk.ReadableLogRecord) {
    onEmitCalledTimes += 1
    onEmitCalledLogRecord = logRecord
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    forceFlushCalledTimes += 1
    return .success
  }

  func shutdown(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
    shutdownCalledTimes += 1
    return .success
  }
}
