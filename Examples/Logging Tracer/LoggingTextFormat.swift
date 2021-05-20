/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class LoggingTextFormat: TextMapPropagator {
    
    var fields = Set<String>()

    func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        Logger.log("LoggingTextFormat.Inject(\(spanContext), ...)")
    }

    func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        Logger.log("LoggingTextFormat.Extract(...)")
        return nil
    }
}
