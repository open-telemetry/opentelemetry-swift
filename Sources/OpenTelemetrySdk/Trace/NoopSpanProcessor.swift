/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

struct NoopSpanProcessor: SpanProcessor {
    init() {}

    let isStartRequired = false
    let isEndRequired = false

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {}

    func shutdown() {}

    func forceFlush() {}
}
