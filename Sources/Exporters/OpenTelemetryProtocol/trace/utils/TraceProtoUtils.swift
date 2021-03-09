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
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftProtobuf

struct TraceProtoUtils {
    static func toProtoSpanId(spanId: SpanId) -> Data {
        var spanIdData = Data(count: SpanId.size)
        spanId.copyBytesTo(dest: &spanIdData, destOffset: 0)
        return spanIdData
    }
    
    static func toProtoTraceId(traceId: TraceId) -> Data {
        var traceIdData = Data(count: TraceId.size)
        traceId.copyBytesTo(dest: &traceIdData, destOffset: 0)
        return traceIdData
    }
    
    static func spanLimitsFromProto(protoTraceConfig: Opentelemetry_Proto_Trace_V1_TraceConfig) -> SpanLimits {
        let spanLimits = SpanLimits()
        spanLimits.settingAttributeCountLimit(UInt(protoTraceConfig.maxNumberOfAttributes))
            .settingEventCountLimit(UInt(protoTraceConfig.maxNumberOfTimedEvents))
            .settingLinkCountLimit(UInt(protoTraceConfig.maxNumberOfLinks))
            .settingAttributePerEventCountLimit(UInt(protoTraceConfig.maxNumberOfAttributesPerTimedEvent))
            .settingAttributePerLinkCountLimit(UInt(protoTraceConfig.maxNumberOfAttributesPerLink))
        return spanLimits
    }
    
    static func fromProtoSampler(protoTraceConfig: Opentelemetry_Proto_Trace_V1_TraceConfig) -> Sampler {
        guard protoTraceConfig.sampler != nil else {
            return Samplers.alwaysOff
        }
        
        switch protoTraceConfig.sampler! {
        case .constantSampler(let constantSampler):
            switch constantSampler.decision {
            case .alwaysOff:
                return Samplers.alwaysOff
            case .alwaysOn:
                return Samplers.alwaysOn
            case .alwaysParent:
                // TODO: add support for alwaysParent
                break
            case .UNRECOGNIZED:
                break
            }
        case .traceIDRatioBased(let ratio):
            return Samplers.traceIdRatio(ratio: ratio.samplingRatio)
        case .rateLimitingSampler:
            // TODO: add support for RateLimiting Sampler
            break
        }
        return Samplers.alwaysOff
    }
}
