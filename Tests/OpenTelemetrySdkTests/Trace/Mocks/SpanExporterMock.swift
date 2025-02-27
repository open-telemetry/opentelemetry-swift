/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

class SpanExporterMock: SpanExporter {
  var exportCalledTimes: Int = 0
  var exportCalledData: [SpanData]?
  var shutdownCalledTimes: Int = 0
  var flushCalled: Bool = false
  var returnValue: SpanExporterResultCode = .success

  func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    exportCalledTimes += 1
    exportCalledData = spans
    return returnValue
  }

  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    flushCalled = true
    return returnValue
  }

  func shutdown(explicitTimeout: TimeInterval?) {
    shutdownCalledTimes += 1
  }
}
