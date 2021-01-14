// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/**
 * Implementation of the TraceContext propagation protocol. See
 * https://github.com/w3c/trace-context
 */
public struct W3CTraceContextPropagator: TextMapPropagator {
    private static let version = "00"
    private static let delimiter: Character = "-"
    private static let versionLength = 2
    private static let delimiterLength = 1
    private static let versionPrefixIdLength = versionLength + delimiterLength
    private static let traceIdLength = 2 * TraceId.size
    private static let versionAndTraceIdLength = versionLength + delimiterLength + traceIdLength + delimiterLength
    private static let spanIdLength = 2 * SpanId.size
    private static let versionAndTraceIdAndSpanIdLength =  versionAndTraceIdLength + spanIdLength + delimiterLength
    private static let optionsLength = 2
    private static let traceparentLengthV0 = versionAndTraceIdAndSpanIdLength + optionsLength

    static let traceparent = "traceparent"
    static let traceState = "traceState"

    public init() {}

    public let fields: Set<String> = [traceState, traceparent]

    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        guard spanContext.isValid else { return }
        var traceparent = W3CTraceContextPropagator.version +
            String(W3CTraceContextPropagator.delimiter) +
            spanContext.traceId.hexString +
            String(W3CTraceContextPropagator.delimiter) +
            spanContext.spanId.hexString +
            String(W3CTraceContextPropagator.delimiter)

        traceparent += spanContext.traceFlags.sampled ? "01" : "00"

        setter.set(carrier: &carrier, key: W3CTraceContextPropagator.traceparent, value: traceparent)

        let traceStateStr = TraceStateUtils.getString(traceState: spanContext.traceState)
        if !traceStateStr.isEmpty {
            setter.set(carrier: &carrier, key: W3CTraceContextPropagator.traceState, value: traceStateStr)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let traceparentCollection = getter.get(carrier: carrier,
                                                     key: W3CTraceContextPropagator.traceparent),
            traceparentCollection.count <= 1 else {
            // multiple traceparent are not allowed
            return nil
        }
        let traceparent = traceparentCollection.first

        guard let extractedTraceParent = extractTraceparent(traceparent: traceparent) else {
            return nil
        }

        let traceStateCollection = getter.get(carrier: carrier, key: W3CTraceContextPropagator.traceState)

        let traceState = extractTraceState(traceStatecollection: traceStateCollection)

        return SpanContext.createFromRemoteParent(traceId: extractedTraceParent.traceId,
                                                  spanId: extractedTraceParent.spanId,
                                                  traceFlags: extractedTraceParent.traceOptions,
                                                  traceState: traceState ?? TraceState())
    }

    private func extractTraceparent(traceparent: String?) -> (traceId: TraceId, spanId: SpanId, traceOptions: TraceFlags)? {
        var traceId = TraceId.invalid
        var spanId = SpanId.invalid
        var traceOptions = TraceFlags()
        var bestAttempt = false

        guard let traceparent = traceparent,
            !traceparent.isEmpty,
            traceparent.count >= W3CTraceContextPropagator.traceparentLengthV0 else {
            return nil
        }

        let traceparentArray = Array(traceparent)

        // if version does not end with delimiter
        if traceparentArray[W3CTraceContextPropagator.versionPrefixIdLength - 1] != W3CTraceContextPropagator.delimiter {
            return nil
        }

        let version0 = UInt8(String(traceparentArray[0]), radix: 16)!
        let version1 = UInt8(String(traceparentArray[1]), radix: 16)!

        if version0 == 0xF && version1 == 0xF {
            return nil
        }

        if version0 > 0 || version1 > 0 {
            // expected version is 00
            // for higher versions - best attempt parsing of trace id, span id, etc.
            bestAttempt = true
        }

        if traceparentArray[W3CTraceContextPropagator.versionAndTraceIdLength - 1] != W3CTraceContextPropagator.delimiter {
            return nil
        }

        traceId = TraceId(fromHexString: String(traceparentArray[W3CTraceContextPropagator.versionPrefixIdLength ... (W3CTraceContextPropagator.versionPrefixIdLength + W3CTraceContextPropagator.traceIdLength)]))
        if !traceId.isValid {
            return nil
        }

        if traceparentArray[W3CTraceContextPropagator.versionAndTraceIdAndSpanIdLength - 1] != W3CTraceContextPropagator.delimiter {
            return nil
        }

        spanId = SpanId(fromHexString: String(traceparentArray[W3CTraceContextPropagator.versionAndTraceIdLength ... (W3CTraceContextPropagator.versionAndTraceIdLength + W3CTraceContextPropagator.spanIdLength)]))

        if !spanId.isValid {
            return nil
        }

        // let options0 = UInt8(String(traceparentArray[TraceContextFormat.versionAndTraceIdAndSpanIdLength]), radix: 16)!
        guard let options1 = UInt8(String(traceparentArray[W3CTraceContextPropagator.versionAndTraceIdAndSpanIdLength + 1]), radix: 16) else {
            return nil
        }

        if (options1 & 1) == 1 {
            traceOptions.setIsSampled(true)
        }

        if !bestAttempt && (traceparent.count != (W3CTraceContextPropagator.versionAndTraceIdAndSpanIdLength + W3CTraceContextPropagator.optionsLength)) {
            return nil
        }

        if bestAttempt {
            if traceparent.count > W3CTraceContextPropagator.traceparentLengthV0 && traceparentArray[W3CTraceContextPropagator.traceparentLengthV0] != W3CTraceContextPropagator.delimiter {
                return nil
            }
        }

        return (traceId, spanId, traceOptions)
    }

    private func extractTraceState(traceStatecollection: [String]?) -> TraceState? {
        guard let traceStatecollection = traceStatecollection,
            !traceStatecollection.isEmpty else { return nil }

        var entries = [TraceState.Entry]()

        for traceState in traceStatecollection.reversed() {
            if !TraceStateUtils.appendTraceState(traceStateString: traceState, traceState: &entries) {
                return nil
            }
        }
        return TraceState(entries: entries)
    }
}
