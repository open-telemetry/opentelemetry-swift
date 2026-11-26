/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Interface that is used by the TracerSdk to generate new SpanId and TraceId.
public protocol IdGenerator {
  /// Generates a new valid SpanId
  func generateSpanId() -> SpanId

  /// Generates a new valid TraceId.
  func generateTraceId() -> TraceId

  /// A boolean indicating whether the trace identifiers produced by this generator
  /// are known to satisfy the randomness requirements of W3C Trace Context Level 2.
  ///
  /// The SDK sets the random trace flag on root spans only when this is `true`.
  var generatesRandomTraceIds: Bool { get }
}

public extension IdGenerator {
  /// Generators that do not opt in are treated as producing non-random trace identifiers,
  /// which preserves the behavior of custom implementations written before the flag existed.
  var generatesRandomTraceIds: Bool {
    false
  }
}
