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
public struct HttpTraceContextFormat: TextFormattable {
    private static let versionLength = "00".count
    private static let versionPrefixIdLength = "00-".count
    private static let traceIdLength = "0af7651916cd43dd8448eb211c80319c".count
    private static let versionAndTraceIdLength = "00-0af7651916cd43dd8448eb211c80319c-".count
    private static let spanIdLength = "00f067aa0ba902b7".count
    private static let versionAndTraceIdAndSpanIdLength = "00-0af7651916cd43dd8448eb211c80319c-00f067aa0ba902b7-".count
    private static let optionsLength = "00".count
    private static let traceparentLengthV0 = "00-0af7651916cd43dd8448eb211c80319c-00f067aa0ba902b7-00".count

    static let traceparent = "traceparent"
    static let traceState = "traceState"

    public init() {}

    public var fields: Set<String> = [traceState, traceparent]

    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        var traceparent = "00-\(spanContext.traceId.hexString)-\(spanContext.spanId.hexString)"

        traceparent += spanContext.traceFlags.sampled ? "-01" : "-00"

        setter.set(carrier: &carrier, key: HttpTraceContextFormat.traceparent, value: traceparent)

        let traceStateStr = TraceStateUtils.getString(traceState: spanContext.traceState)
        if !traceStateStr.isEmpty {
            setter.set(carrier: &carrier, key: HttpTraceContextFormat.traceState, value: traceStateStr)
        }
    }

    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext where G: Getter {
        guard let traceparentCollection = getter.get(carrier: carrier,
                                                     key: HttpTraceContextFormat.traceparent),
            traceparentCollection.count <= 1 else {
            // multiple traceparent are not allowed
            return SpanContext.invalid
        }
        let traceparent = traceparentCollection.first

        guard let extractedTraceParent = extractTraceparent(traceparent: traceparent) else {
            return SpanContext.invalid
        }

        let traceStateCollection = getter.get(carrier: carrier, key: HttpTraceContextFormat.traceState)

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
            traceparent.count >= HttpTraceContextFormat.traceparentLengthV0 else {
            return nil
        }

        let traceparentArray = Array(traceparent)

        // if version does not end with delimiter
        if traceparentArray[HttpTraceContextFormat.versionPrefixIdLength - 1] != "-" {
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

        if traceparentArray[HttpTraceContextFormat.versionAndTraceIdLength - 1] != "-" {
            return nil
        }

        traceId = TraceId(fromHexString: String(traceparentArray[HttpTraceContextFormat.versionPrefixIdLength ... (HttpTraceContextFormat.versionPrefixIdLength + HttpTraceContextFormat.traceIdLength)]))
        if !traceId.isValid {
            return nil
        }

        if traceparentArray[HttpTraceContextFormat.versionAndTraceIdAndSpanIdLength - 1] != "-" {
            return nil
        }

        spanId = SpanId(fromHexString: String(traceparentArray[HttpTraceContextFormat.versionAndTraceIdLength ... (HttpTraceContextFormat.versionAndTraceIdLength + HttpTraceContextFormat.spanIdLength)]))

        if !spanId.isValid {
            return nil
        }

        // let options0 = UInt8(String(traceparentArray[TraceContextFormat.versionAndTraceIdAndSpanIdLength]), radix: 16)!
        guard let options1 = UInt8(String(traceparentArray[HttpTraceContextFormat.versionAndTraceIdAndSpanIdLength + 1]), radix: 16) else {
            return nil
        }

        if (options1 & 1) == 1 {
            traceOptions.setIsSampled(true)
        }

        if !bestAttempt && (traceparent.count != (HttpTraceContextFormat.versionAndTraceIdAndSpanIdLength + HttpTraceContextFormat.optionsLength)) {
            return nil
        }

        if bestAttempt {
            if traceparent.count > HttpTraceContextFormat.traceparentLengthV0 && traceparentArray[HttpTraceContextFormat.traceparentLengthV0] != "-" {
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
