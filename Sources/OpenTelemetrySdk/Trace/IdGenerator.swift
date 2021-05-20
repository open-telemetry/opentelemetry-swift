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
}
