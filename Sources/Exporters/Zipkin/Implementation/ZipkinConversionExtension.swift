/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct ZipkinConversionExtension {
    static let statusCode = "otel.status_code"
    static let statusErrorDescription = "error"

    static let remoteEndpointServiceNameKeyResolution = ["peer.service": 0,
                                                         "net.peer.name": 1,
                                                         "peer.hostname": 2,
                                                         "peer.address": 2,
                                                         "http.host": 3,
                                                         "db.instance": 4]

    static var localEndpointCache = [String: ZipkinEndpoint]()
    static var remoteEndpointCache = [String: ZipkinEndpoint]()

    static let defaultServiceName = "unknown_service:" + ProcessInfo.processInfo.processName

    struct AttributeEnumerationState {
        var tags = [String: String]()
        var RemoteEndpointServiceName: String?
        var remoteEndpointServiceNamePriority: Int?
        var serviceName: String?
        var serviceNamespace: String?
    }

    static func toZipkinSpan(otelSpan: SpanData, defaultLocalEndpoint: ZipkinEndpoint, useShortTraceIds: Bool = false) -> ZipkinSpan {
        let parentId = otelSpan.parentSpanId?.hexString ?? SpanId.invalid.hexString

        var attributeEnumerationState = AttributeEnumerationState()

        otelSpan.attributes.forEach {
            processAttributes(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        otelSpan.resource.attributes.forEach {
            processResources(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        var localEndpoint = defaultLocalEndpoint

        if let serviceName = attributeEnumerationState.serviceName, !serviceName.isEmpty, defaultServiceName != serviceName {
            if localEndpointCache[serviceName] == nil {
                localEndpointCache[serviceName] = defaultLocalEndpoint.clone(serviceName: serviceName)
            }
            localEndpoint = localEndpointCache[serviceName] ?? localEndpoint
        }

        if let serviceNamespace = attributeEnumerationState.serviceNamespace, !serviceNamespace.isEmpty {
            attributeEnumerationState.tags["service.namespace"] = serviceNamespace
        }

        var remoteEndpoint: ZipkinEndpoint?
        if otelSpan.kind == .client || otelSpan.kind == .producer, attributeEnumerationState.RemoteEndpointServiceName != nil {
            remoteEndpoint = remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!]
            if remoteEndpoint == nil {
                remoteEndpoint = ZipkinEndpoint(serviceName: attributeEnumerationState.RemoteEndpointServiceName!)
                remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!] = remoteEndpoint!
            }
        }

        let status = otelSpan.status
        if status != .unset {
            attributeEnumerationState.tags[statusCode] = "\(status.name)".uppercased()
        }
        if case let Status.error(description) = status {
            attributeEnumerationState.tags[statusErrorDescription] = description
        }

        let annotations = otelSpan.events.map { processEvents(event: $0) }

        return ZipkinSpan(traceId: ZipkinConversionExtension.EncodeTraceId(traceId: otelSpan.traceId, useShortTraceIds: useShortTraceIds),
                          parentId: parentId,
                          id: ZipkinConversionExtension.EncodeSpanId(spanId: otelSpan.spanId),
                          kind: ZipkinConversionExtension.toSpanKind(otelSpan: otelSpan),
                          name: otelSpan.name,
                          timestamp: otelSpan.startTime.timeIntervalSince1970.toMicroseconds,
                          duration: otelSpan.endTime.timeIntervalSince(otelSpan.startTime).toMicroseconds,
                          localEndpoint: localEndpoint,
                          remoteEndpoint: remoteEndpoint,
                          annotations: annotations,
                          tags: attributeEnumerationState.tags,
                          debug: nil,
                          shared: nil)
    }

    static func EncodeSpanId(spanId: SpanId) -> String {
        return spanId.hexString
    }

    private static func EncodeTraceId(traceId: TraceId, useShortTraceIds: Bool) -> String {
        if useShortTraceIds {
            return String(format: "%016llx", traceId.rawLowerLong)
        } else {
            return traceId.hexString
        }
    }

    private static func toSpanKind(otelSpan: SpanData) -> String? {
        switch otelSpan.kind {
        case .client:
            return "CLIENT"
        case .server:
            return "SERVER"
        case .producer:
            return "PRODUCER"
        case .consumer:
            return "CONSUMER"
        default:
            return nil
        }
    }

    private static func processEvents(event: SpanData.Event) -> ZipkinAnnotation {
        return ZipkinAnnotation(timestamp: event.timestamp.timeIntervalSince1970.toMicroseconds, value: event.name)
    }

    private static func processAttributes(state: inout AttributeEnumerationState, key: String, value: AttributeValue) {
        if case let .string(val) = value, let priority = remoteEndpointServiceNameKeyResolution[key] {
            if state.RemoteEndpointServiceName == nil || priority < state.remoteEndpointServiceNamePriority ?? 5 {
                state.RemoteEndpointServiceName = val
                state.remoteEndpointServiceNamePriority = priority
            }
            state.tags[key] = val
        } else {
            state.tags[key] = value.description
        }
    }

    private static func processResources(state: inout AttributeEnumerationState, key: String, value: AttributeValue) {
        if case let .string(val) = value {
            if key == ResourceAttributes.serviceName {
                state.serviceName = val
            } else if key == ResourceAttributes.serviceNamespace {
                state.serviceNamespace = val
            } else {
                state.tags[key] = val
            }
        } else {
            state.tags[key] = value.description
        }
    }
}
