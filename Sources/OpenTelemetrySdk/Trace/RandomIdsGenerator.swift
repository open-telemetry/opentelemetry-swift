/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public struct RandomIdGenerator: IdGenerator {
    public init() {}

    public func generateSpanId() -> SpanId {
        var id: UInt64
        repeat {
            id = UInt64.random(in: .min ... .max)
        } while id == SpanId.invalidId
        return SpanId(id: id)
    }

    public func generateTraceId() -> TraceId {
        var idHi: UInt64
        var idLo: UInt64
        repeat {
            idHi = UInt64.random(in: .min ... .max)
            idLo = UInt64.random(in: .min ... .max)
        } while idHi == TraceId.invalidId && idLo == TraceId.invalidId
        return TraceId(idHi: idHi, idLo: idLo)
    }
}
