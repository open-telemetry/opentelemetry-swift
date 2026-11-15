/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// No-op implementation of the Tracer
public final class DefaultTracer: Tracer, Sendable {
  public static let instance = DefaultTracer()

  public func spanBuilder(spanName: String) -> SpanBuilder {
    return PropagatedSpanBuilder(tracer: self, spanName: spanName)
  }
}
