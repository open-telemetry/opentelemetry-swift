/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class LoggingTextFormat: TextMapPropagator {
  var fields = Set<String>()

  func inject(spanContext: SpanContext, carrier: inout [String: String], setter: some Setter) {
    Logger.log("LoggingTextFormat.Inject(\(spanContext), ...)")
  }

  func extract(carrier: [String: String], getter: some Getter) -> SpanContext? {
    Logger.log("LoggingTextFormat.Extract(...)")
    return nil
  }
}
