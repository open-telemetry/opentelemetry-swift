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
 * Implementation of the B3 propagation protocol. See
 * https://github.com/openzipkin/b3-propagation
 */
public class B3Propagator: TextMapPropagator {
    public static let traceIdHeader = "X-B3-TraceId"
    public static let spanIdHeader = "X-B3-SpanId"
    public static let sampledHeader = "X-B3-Sampled"
    public static let trueInt = "1"
    public static let falseInt = "0"
    public static let combinedHeader = "b3"
    public static let combinedHeaderDelimiter = "-"
    
    public let fields: Set<String> = [traceIdHeader, spanIdHeader, sampledHeader]
    
    private static let maxTraceIdLength = 2 * TraceId.size
    private static let maxSpanIdLength = 2 * SpanId.size
    private static let sampledFlags: TraceFlags = TraceFlags().settingIsSampled(true)
    private static let notSampledFlags: TraceFlags = TraceFlags().settingIsSampled(false)
    
    private var singleHeader: Bool
    
    /// Creates a new instance of B3Propagator. Default to use multiple headers.
    public init() {
        self.singleHeader = false
    }
    
    /// Creates a new instance of B3Propagator
    /// - Parameters:
    ///     - singleHeader: whether to use single or multiple headers
    public init(_ singleHeader: Bool) {
        self.singleHeader = singleHeader
    }
    
    public func inject<S>(spanContext: SpanContext, carrier: inout [String: String], setter: S) where S: Setter {
        let sampled = spanContext.traceFlags.sampled ? B3Propagator.trueInt : B3Propagator.falseInt
        if singleHeader {
            setter.set(carrier: &carrier, key: B3Propagator.combinedHeader, value: "\(spanContext.traceId.hexString)\(B3Propagator.combinedHeaderDelimiter)\(spanContext.spanId.hexString)\(B3Propagator.combinedHeaderDelimiter)\(sampled)")
        } else {
            setter.set(carrier: &carrier, key: B3Propagator.traceIdHeader, value: spanContext.traceId.hexString)
            setter.set(carrier: &carrier, key: B3Propagator.spanIdHeader, value: spanContext.spanId.hexString)
            setter.set(carrier: &carrier, key: B3Propagator.sampledHeader, value: sampled)
        }
    }
    
    public func extract<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        var spanContext: SpanContext?
        
        if singleHeader {
            spanContext = getSpanContextFromSingleHeader(carrier: carrier, getter: getter)
        } else {
            spanContext = getSpanContextFromMultipleHeaders(carrier: carrier, getter: getter)
        }
        
        return spanContext
    }
    
    private func getSpanContextFromSingleHeader<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let value = getter.get(carrier: carrier, key: B3Propagator.combinedHeader), value.count >= 1 else {
            print("Missing or empty combined header: \(B3Propagator.combinedHeader). Returning INVALID span context.")
            return SpanContext.invalid
        }
        
        let parts: [String] = value[0].split(separator: "-").map { String($0) }
        
        //  must have between 2 and 4 hyphen delimited parts:
        //  traceId-spanId-sampled-parentSpanId (last two are optional)
        if parts.count < 2 || parts.count > 4 {
            print("Invalid combined header '\(B3Propagator.combinedHeader)'. Returning INVALID span Context")
            return SpanContext.invalid
        }
        
        let traceId = parts[0]
        if !isTraceIdValid(traceId) {
            print("Invalid TraceId in B3 header: \(B3Propagator.combinedHeader). Returning INVALID span context.")
            return SpanContext.invalid
        }
        
        let spanId = parts[1]
        if !isSpanIdValid(spanId) {
            print("Invalid SpanId in B3 header: \(B3Propagator.combinedHeader). Returning INVALID span context.")
            return SpanContext.invalid
        }
        
        let sampled: String? = parts.count >= 3 ? parts[2] : nil
        
        return buildSpanContext(traceId: traceId, spanId: spanId, sampled: sampled)
    }
    
    private func getSpanContextFromMultipleHeaders<G>(carrier: [String: String], getter: G) -> SpanContext? where G: Getter {
        guard let traceIdCollection = getter.get(carrier: carrier, key: B3Propagator.traceIdHeader), traceIdCollection.count >= 1, isTraceIdValid(traceIdCollection[0]) else {
            print("Invalid TraceId in B3 header: \(B3Propagator.combinedHeader). Returning INVALID span context.")
            return SpanContext.invalid
        }
        
        let traceId = traceIdCollection[0]
        
        guard let spanIdCollection = getter.get(carrier: carrier, key: B3Propagator.spanIdHeader), spanIdCollection.count >= 0, isSpanIdValid(spanIdCollection[0]) else {
            print("Invalid SpanId in B3 header: \(B3Propagator.combinedHeader). Returning INVALID span context.")
            return SpanContext.invalid
        }
        
        let spanId = spanIdCollection[0]
        
        guard let sampledCollection = getter.get(carrier: carrier, key: B3Propagator.sampledHeader), sampledCollection.count >= 1 else {
            return buildSpanContext(traceId: traceId, spanId: spanId, sampled: nil)
        }
        
        return buildSpanContext(traceId: traceId, spanId: spanId, sampled: sampledCollection.first)
    }
    
    private func buildSpanContext(traceId: String, spanId: String, sampled: String?) -> SpanContext {
        if let sampled = sampled {
            let traceFlags = (sampled == B3Propagator.trueInt || sampled == "true") ? B3Propagator.sampledFlags : B3Propagator.notSampledFlags
            return SpanContext.createFromRemoteParent(traceId: TraceId(fromHexString: traceId), spanId: SpanId(fromHexString: spanId), traceFlags: traceFlags, traceState: TraceState())
        } else {
            print("Error parsing B3 header. Returning INVALID span content.")
            return SpanContext.invalid
        }
    }
    
    private func isTraceIdValid(_ traceId: String) -> Bool {
        return !(traceId.isEmpty || traceId.count > B3Propagator.maxTraceIdLength)
    }
    
    private func isSpanIdValid(_ spanId: String) -> Bool {
        return !(spanId.isEmpty || spanId.count > B3Propagator.maxSpanIdLength)
    }
}
