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

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        exportCalledTimes += 1
        exportCalledData = spans
        return returnValue
    }

    func flush() -> SpanExporterResultCode {
        flushCalled = true
        return returnValue
    }

    func shutdown() {
        shutdownCalledTimes += 1
    }
}
