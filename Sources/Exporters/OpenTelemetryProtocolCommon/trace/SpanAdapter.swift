/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct SpanAdapter {
  public static func toProtoResourceSpans(spanDataList: [SpanData]) -> [Opentelemetry_Proto_Trace_V1_ResourceSpans] {
    let resourceAndScopeMap = groupByResourceAndScope(spanDataList: spanDataList)
    var resourceSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
    resourceAndScopeMap.forEach { resMap in
      var scopeSpans = [Opentelemetry_Proto_Trace_V1_ScopeSpans]()
      resMap.value.forEach { instScope in
        var protoInst = Opentelemetry_Proto_Trace_V1_ScopeSpans()
        protoInst.scope = CommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: instScope.key)
        instScope.value.forEach {
          protoInst.spans.append($0)
        }
        scopeSpans.append(protoInst)
      }
      
      var resourceSpan = Opentelemetry_Proto_Trace_V1_ResourceSpans()
      resourceSpan.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
      resourceSpan.scopeSpans.append(contentsOf: scopeSpans)
      resourceSpans.append(resourceSpan)
    }
    return resourceSpans
  }
  
  private static func groupByResourceAndScope(spanDataList: [SpanData]) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Trace_V1_Span]]] {
    var result = [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Trace_V1_Span]]]()
    spanDataList.forEach {
      result[$0.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Trace_V1_Span]]()][$0.instrumentationScope, default: [Opentelemetry_Proto_Trace_V1_Span]()]
        .append(toProtoSpan(spanData: $0))
    }
    return result
  }
  
  public static func toProtoSpan(spanData: SpanData) -> Opentelemetry_Proto_Trace_V1_Span {
    var protoSpan = Opentelemetry_Proto_Trace_V1_Span()
    protoSpan.traceID = TraceProtoUtils.toProtoTraceId(traceId: spanData.traceId)
    protoSpan.spanID = TraceProtoUtils.toProtoSpanId(spanId: spanData.spanId)
    if let parentId = spanData.parentSpanId {
      protoSpan.parentSpanID = TraceProtoUtils.toProtoSpanId(spanId: parentId)
    }
    protoSpan.name = spanData.name
    protoSpan.kind = toProtoSpanKind(kind: spanData.kind)
    protoSpan.startTimeUnixNano = spanData.startTime.timeIntervalSince1970.toNanoseconds
    protoSpan.endTimeUnixNano = spanData.endTime.timeIntervalSince1970.toNanoseconds
    spanData.attributes.forEach {
      protoSpan.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    protoSpan.droppedAttributesCount = UInt32(spanData.totalAttributeCount - spanData.attributes.count)
    spanData.events.forEach {
      protoSpan.events.append(toProtoSpanEvent(event: $0))
    }
    protoSpan.droppedEventsCount = UInt32(spanData.totalRecordedEvents - spanData.events.count)
    
    spanData.links.forEach {
      protoSpan.links.append(toProtoSpanLink(link: $0))
    }
    protoSpan.droppedLinksCount = UInt32(spanData.totalRecordedLinks - spanData.links.count)
    protoSpan.status = toStatusProto(status: spanData.status)
    return protoSpan
  }
  
  public static func toProtoSpanKind(kind: SpanKind) -> Opentelemetry_Proto_Trace_V1_Span.SpanKind {
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
  
  public static func toProtoSpanEvent(event: SpanData.Event) -> Opentelemetry_Proto_Trace_V1_Span.Event {
    var protoEvent = Opentelemetry_Proto_Trace_V1_Span.Event()
    protoEvent.name = event.name
    protoEvent.timeUnixNano = event.timestamp.timeIntervalSince1970.toNanoseconds
    event.attributes.forEach {
      protoEvent.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    return protoEvent
  }
  
  public static func toProtoSpanLink(link: SpanData.Link) -> Opentelemetry_Proto_Trace_V1_Span.Link {
    var protoLink = Opentelemetry_Proto_Trace_V1_Span.Link()
    protoLink.traceID = TraceProtoUtils.toProtoTraceId(traceId: link.context.traceId)
    protoLink.spanID = TraceProtoUtils.toProtoSpanId(spanId: link.context.spanId)
    link.attributes.forEach {
      protoLink.attributes.append(CommonAdapter.toProtoAttribute(key: $0.key, attributeValue: $0.value))
    }
    return protoLink
  }
  
  public static func toStatusProto(status: Status) -> Opentelemetry_Proto_Trace_V1_Status {
    var statusProto = Opentelemetry_Proto_Trace_V1_Status()
    switch status {
    case .ok:
      statusProto.code = .ok
    case .unset:
      statusProto.code = .unset
    case .error(let description):
      statusProto.code = .error
      statusProto.message = description
    }
    return statusProto
  }
}
