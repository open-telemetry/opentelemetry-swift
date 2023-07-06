/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftProtobuf

struct TraceProtoUtils {
  static func toProtoSpanId(spanId: SpanId) -> Data {
    var spanIdData = Data(count: SpanId.size)
    spanId.copyBytesTo(dest: &spanIdData, destOffset: 0)
    return spanIdData
  }
  
  static func toProtoTraceId(traceId: TraceId) -> Data {
    var traceIdData = Data(count: TraceId.size)
    traceId.copyBytesTo(dest: &traceIdData, destOffset: 0)
    return traceIdData
  }
}
