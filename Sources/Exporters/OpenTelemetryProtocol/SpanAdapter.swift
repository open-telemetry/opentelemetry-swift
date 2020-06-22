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
struct SpanAdapter {
    static func toProtoResourceSpans(spanDataList: [SpanData]) -> [Opentelemetry_Proto_Trace_V1_ResourceSpans] {
        let resourceAndLibraryMap = groupByResourceAndLibrary(spanDataList: spanDataList)
        var resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
        resourceAndLibraryMap.forEach { resMap in
            var instrumentationLibrarySpans = [Opentelemetry_Proto_Trace_V1_InstrumentationLibrarySpans]()
            resMap.value.forEach { instLibrary in
                var protoInst = Opentelemetry_Proto_Trace_V1_InstrumentationLibrarySpans()
                protoInst.instrumentationLibrary = CommonAdapter.toProtoInstrumentationLibrary(instrumentationLibraryInfo: instLibrary.key)
                instLibrary.value.forEach {
                    protoInst.spans.append($0)
                }
                instrumentationLibrarySpans.append(protoInst)
            }

            var resourceSpan = Opentelemetry_Proto_Trace_V1_ResourceSpans()
            resourceSpan.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
            resourceSpan.instrumentationLibrarySpans.append(contentsOf: instrumentationLibrarySpans)
            resourceSpans.append(resourceSpan)
        }
        return resourceSpans
    }

    private static func groupByResourceAndLibrary(spanDataList: [SpanData]) -> [Resource: [InstrumentationLibraryInfo: [Opentelemetry_Proto_Trace_V1_Span]]] {
        var result = [Resource: [InstrumentationLibraryInfo: [Opentelemetry_Proto_Trace_V1_Span]]]()
        spanDataList.forEach {
            let resource = $0.resource
            var libraryInfo = result[resource]
            if result[resource] == nil {
                libraryInfo = [InstrumentationLibraryInfo: [Opentelemetry_Proto_Trace_V1_Span]]()
                result[resource] = libraryInfo
            }
            var spanList = libraryInfo![$0.instrumentationLibraryInfo]
            if spanList == nil {
                spanList = [Opentelemetry_Proto_Trace_V1_Span]()
                libraryInfo![$0.instrumentationLibraryInfo] = spanList
            }
            spanList!.append(toProtoSpan(spanData: $0))
        }
        return result
    }

    static func toProtoSpan(spanData: SpanData) -> Opentelemetry_Proto_Trace_V1_Span {
        var protoSpan = Opentelemetry_Proto_Trace_V1_Span()
        protoSpan.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanData.traceId)
        protoSpan.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanData.spanId)
        if let parentId = spanData.parentSpanId {
            protoSpan.parentSpanID = TraceProtoUtils.toProtoSpanId(spanId: parentId)
        }
        protoSpan.name = spanData.name
        protoSpan.kind = toProtoSpanKind(kind: spanData.kind)
        protoSpan.startTimeUnixNano = spanData.startEpochNanos
        protoSpan.endTimeUnixNano = spanData.endEpochNanos
        spanData.attributes.forEach {
            protoSpan.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
        }
        protoSpan.droppedAttributesCount = UInt32(spanData.attributes.count - spanData.attributes.capacity)
        spanData.timedEvents.forEach {
            protoSpan.events.append(toProtoSpanEvent(event: $0))
        }
        protoSpan.droppedEventsCount = UInt32(spanData.timedEvents.count - spanData.timedEvents.capacity)

        spanData.links.forEach {
            protoSpan.links.append(toProtoSpanLink(link: $0))
        }
        protoSpan.droppedLinksCount = UInt32(spanData.links.count - spanData.links.capacity)
        protoSpan.status = toStatusProto(status: spanData.status)
        return protoSpan
    }

    static func toProtoSpanKind(kind: SpanKind) -> Opentelemetry_Proto_Trace_V1_Span.SpanKind {
        switch kind {
        case .internal:
            return Opentelemetry_Proto_Trace_V1_Span.SpanKind.internal
        case .server:
            return Opentelemetry_Proto_Trace_V1_Span.SpanKind.server
        case .client:
            return Opentelemetry_Proto_Trace_V1_Span.SpanKind.client
        case .producer:
            return Opentelemetry_Proto_Trace_V1_Span.SpanKind.producer
        case .consumer:
            return Opentelemetry_Proto_Trace_V1_Span.SpanKind.consumer
        }
    }

    static func toProtoSpanEvent(event: SpanData.TimedEvent) -> Opentelemetry_Proto_Trace_V1_Span.Event {
        var protoEvent = Opentelemetry_Proto_Trace_V1_Span.Event()
        protoEvent.name = event.name
        protoEvent.timeUnixNano = event.epochNanos
        event.attributes.forEach {
            protoEvent.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
        }
        protoEvent.droppedAttributesCount = UInt32(event.attributes.count - event.attributes.capacity)
        return protoEvent
    }

    static func toProtoSpanLink(link: Link) -> Opentelemetry_Proto_Trace_V1_Span.Link {
        var protoLink = Opentelemetry_Proto_Trace_V1_Span.Link()
        protoLink.traceID = TraceProtoUtils.toProtoTraceId(traceId: link.context.traceId)
        protoLink.spanID = TraceProtoUtils.toProtoSpanId(spanId: link.context.spanId)
        link.attributes.forEach {
            protoLink.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
        }
        protoLink.droppedAttributesCount = UInt32(link.attributes.count - link.attributes.capacity)

        return protoLink
    }

    static func toStatusProto(status: Status?) -> Opentelemetry_Proto_Trace_V1_Status {
        var statusProto = Opentelemetry_Proto_Trace_V1_Status()
        statusProto.code = Opentelemetry_Proto_Trace_V1_Status.StatusCode(rawValue: status?.canonicalCode.rawValue ?? 0) ?? .ok
        if let desc = status?.statusDescription {
            statusProto.message = desc
        }
        return statusProto
    }
}
