/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Implementation of the SpanExporter that simply forwards all received spans to a list of
/// SpanExporter.
/// Can be used to export to multiple backends using the same SpanProcessor} like a impleSampledSpansProcessor
///  or a BatchSampledSpansProcessor.
public class MultiSpanExporter: SpanExporter {
  var spanExporters: [SpanExporter]

  public init(spanExporters: [SpanExporter]) {
    self.spanExporters = spanExporters
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    var currentResultCode = SpanExporterResultCode.success
    for exporter in spanExporters {
      currentResultCode.mergeResultCode(newResultCode: exporter.export(spans: spans, explicitTimeout: explicitTimeout))
    }
    return currentResultCode
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    var currentResultCode = SpanExporterResultCode.success
    for exporter in spanExporters {
      currentResultCode.mergeResultCode(newResultCode: exporter.flush(explicitTimeout: explicitTimeout))
    }
    return currentResultCode
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    for exporter in spanExporters {
      exporter.shutdown(explicitTimeout: explicitTimeout)
    }
  }
}
