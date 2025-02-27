/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// No-op implementation of the Tracer
public class DefaultTracer: Tracer {
  public static var instance = DefaultTracer()

  public func spanBuilder(spanName: String) -> SpanBuilder {
    return PropagatedSpanBuilder(tracer: self, spanName: spanName)
  }
}
