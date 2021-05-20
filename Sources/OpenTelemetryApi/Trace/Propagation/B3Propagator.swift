/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 * Implementation of the B3 propagation protocol. See
 * https://github.com/openzipkin/b3-propagation
 */
public class B3Propagator: TextMapPropagator {
    static let traceIdHeader = "X-B3-TraceId"
    static let spanIdHeader = "X-B3-SpanId"
    static let sampledHeader = "X-B3-Sampled"
    static let trueInt = "1"
    static let falseInt = "0"
    static let combinedHeader = "b3"
    static let combinedHeaderDelimiter = "-"

    public let fields: Set<String> = [traceIdHeader, spanIdHeader, sampledHeader]

    private static let maxTraceIdLength = 2 * TraceId.size
    private static let maxSpanIdLength = 2 * SpanId.size
    private static let sampledFlags = TraceFlags().settingIsSampled(true)
    private static let notSampledFlags = TraceFlags().settingIsSampled(false)

    private var singleHeaderInjection: Bool

    /// Creates a new instance of B3Propagator. Default to use multiple headers.
    public init() {
        self.singleHeaderInjection = false
    }

    /// Creates a new instance of B3Propagator
    /// - Parameters:
    ///     - singleHeader: whether to use single or multiple headers
    public init(_ singleHeaderInjection: Bool) {
        self.singleHeaderInjection = singleHeaderInjection
    }

    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        let sampled = spanContext.traceFlags.sampled ? B3Propagator.trueInt : B3Propagator.falseInt
        if singleHeaderInjection {
            setter.set(carrier: &carrier, key: B3Propagator.combinedHeader, value: "\(spanContext.traceId.hexString)\(B3Propagator.combinedHeaderDelimiter)\(spanContext.spanId.hexString)\(B3Propagator.combinedHeaderDelimiter)\(sampled)")
        } else {
            setter.set(carrier: &carrier, key: B3Propagator.traceIdHeader, value: spanContext.traceId.hexString)
            setter.set(carrier: &carrier, key: B3Propagator.spanIdHeader, value: spanContext.spanId.hexString)
            setter.set(carrier: &carrier, key: B3Propagator.sampledHeader, value: sampled)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        var spanContext: SpanContext?

        spanContext = getSpanContextFromSingleHeader(carrier: carrier, getter: getter)
        if spanContext == nil {
            spanContext = getSpanContextFromMultipleHeaders(carrier: carrier, getter: getter)
        }
        if spanContext == nil {
            print("Invalid SpanId in B3 header. Returning no span context.")
        }

        return spanContext
    }

    private func getSpanContextFromSingleHeader<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let value = getter.get(carrier: carrier, key: B3Propagator.combinedHeader), value.count >= 1 else {
            return nil
        }

        let parts: [String] = value[0].split(separator: "-").map { String($0) }

        //  must have between 2 and 4 hyphen delimited parts:
        //  traceId-spanId-sampled-parentSpanId (last two are optional)
        if parts.count < 2 || parts.count > 4 {
            return nil
        }

        let traceId = parts[0]
        if !isTraceIdValid(traceId) {
            return nil
        }

        let spanId = parts[1]
        if !isSpanIdValid(spanId) {
            return nil
        }

        let sampled: String? = parts.count >= 3 ? parts[2] : nil

        return buildSpanContext(traceId: traceId, spanId: spanId, sampled: sampled)
    }

    private func getSpanContextFromMultipleHeaders<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let traceIdCollection = getter.get(carrier: carrier, key: B3Propagator.traceIdHeader), traceIdCollection.count >= 1, isTraceIdValid(traceIdCollection[0]) else {
            return nil
        }

        let traceId = traceIdCollection[0]

        guard let spanIdCollection = getter.get(carrier: carrier, key: B3Propagator.spanIdHeader), spanIdCollection.count >= 0, isSpanIdValid(spanIdCollection[0]) else {
            return nil
        }

        let spanId = spanIdCollection[0]

        guard let sampledCollection = getter.get(carrier: carrier, key: B3Propagator.sampledHeader), sampledCollection.count >= 1 else {
            return buildSpanContext(traceId: traceId, spanId: spanId, sampled: nil)
        }

        return buildSpanContext(traceId: traceId, spanId: spanId, sampled: sampledCollection.first)
    }

    private func buildSpanContext(traceId: String, spanId: String, sampled: String?) -> SpanContext? {
        if let sampled = sampled {
            let traceFlags = (sampled == B3Propagator.trueInt || sampled == "true") ? B3Propagator.sampledFlags : B3Propagator.notSampledFlags
            let returnContext = SpanContext.createFromRemoteParent(traceId: TraceId(fromHexString: traceId), spanId: SpanId(fromHexString: spanId), traceFlags: traceFlags, traceState: TraceState())
            return returnContext.isValid ? returnContext : nil
        } else {
            return nil
        }
    }

    private func isTraceIdValid(_ traceId: String) -> Bool {
        return !(traceId.isEmpty || traceId.count > B3Propagator.maxTraceIdLength)
    }

    private func isSpanIdValid(_ spanId: String) -> Bool {
        return !(spanId.isEmpty || spanId.count > B3Propagator.maxSpanIdLength)
    }
}
