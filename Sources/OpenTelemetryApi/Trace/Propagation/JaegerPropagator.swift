/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 * Implementation of the Jaeger propagation protocol. See
 * https://www.jaegertracing.io/docs/client-libraries/#propagation-format
 */

public class JaegerPropagator: TextMapPropagator {
    static let propagationHeader = "uber-trace-id"
    // Parent span has been deprecated but Jaeger propagation protocol requires it
    static let deprecatedParentSpan = "0"
    static let propagationHeaderDelimiter: Character = ":"

    private static let maxTraceIdLength = 2 * TraceId.size
    private static let maxSpanIdLength = 2 * SpanId.size
    private static let maxFlagsLength = 2

    private static let isSampledChar = "1"
    private static let notSampledChar = "0"

    private static let sampledFlags = TraceFlags().settingIsSampled(true)
    private static let notSampledFlags = TraceFlags().settingIsSampled(false)

    public var fields: Set<String> = [propagationHeader]

    public init() {}

    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        guard spanContext.traceId.isValid, spanContext.spanId.isValid else {
            return
        }
        var propagation = ""
        propagation += spanContext.traceId.hexString
        propagation += String(JaegerPropagator.propagationHeaderDelimiter)
        propagation += spanContext.spanId.hexString
        propagation += String(JaegerPropagator.propagationHeaderDelimiter)
        propagation += JaegerPropagator.deprecatedParentSpan
        propagation += String(JaegerPropagator.propagationHeaderDelimiter)
        propagation += spanContext.isSampled ? JaegerPropagator.isSampledChar : JaegerPropagator.notSampledChar
        setter.set(carrier: &carrier, key: JaegerPropagator.propagationHeader, value: propagation)
    }

    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let headerValue = getter.get(carrier: carrier, key: JaegerPropagator.propagationHeader), headerValue.count >= 1 else {
            return nil
        }

        var header = headerValue[0]
        if header.lastIndex(of: JaegerPropagator.propagationHeaderDelimiter) == nil {
            guard let decodedHeader = header.removingPercentEncoding,
                  let _ = decodedHeader.lastIndex(of: JaegerPropagator.propagationHeaderDelimiter)
            else {
                return nil
            }
            header = decodedHeader
        }

        let parts = header.split(separator: JaegerPropagator.propagationHeaderDelimiter)
        guard parts.count == 4 else {
            return nil
        }

        let traceId = String(parts[0])
        if !isTraceIdValid(traceId) {
            return nil
        }

        let spanId = String(parts[1])
        if !isSpanIdValid(spanId) {
            return nil
        }

        let flags = String(parts[3])
        if !isFlagValid(flags) {
            return nil
        }

        return buildSpanContext(traceId: traceId, spanId: spanId, flags: flags)
    }

    private func buildSpanContext(traceId: String, spanId: String, flags: String) -> SpanContext? {
        let flagsInt = Int(flags) ?? 0
        let traceFlags = ((flagsInt & 1) == 1) ? JaegerPropagator.sampledFlags : JaegerPropagator.notSampledFlags
        let context = SpanContext.createFromRemoteParent(traceId: TraceId(fromHexString: traceId),
                                                  spanId: SpanId(fromHexString: spanId),
                                                  traceFlags: traceFlags,
                                                  traceState: TraceState())
        return context.isValid ? context : nil
    }

    private func isTraceIdValid(_ traceId: String) -> Bool {
        return !(traceId.isEmpty || traceId.count > JaegerPropagator.maxTraceIdLength)
    }

    private func isSpanIdValid(_ spanId: String) -> Bool {
        return !(spanId.isEmpty || spanId.count > JaegerPropagator.maxSpanIdLength)
    }

    private func isFlagValid(_ flags: String) -> Bool {
        return !(flags.isEmpty || flags.count > JaegerPropagator.maxFlagsLength)
    }
}
