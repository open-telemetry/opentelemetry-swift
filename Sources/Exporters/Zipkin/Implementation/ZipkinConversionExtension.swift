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

struct ZipkinConversionExtension {
    static let statusCode = "ot.status_code"
    static let statusDescription = "ot.status_description"

    static let remoteEndpointServiceNameKeyResolution = ["peer.service": 0,
                                                         "net.peer.name": 1,
                                                         "peer.hostname": 2,
                                                         "peer.address": 2,
                                                         "http.host": 3,
                                                         "db.instance": 4]

    static var localEndpointCache = [String: ZipkinEndpoint]()
    static var remoteEndpointCache = [String: ZipkinEndpoint]()

    struct AttributeEnumerationState {
        var tags = [String: String]()
        var RemoteEndpointServiceName: String?
        var remoteEndpointServiceNamePriority: Int?
        var serviceName: String?
        var serviceNamespace: String?
    }

    static func toZipkinSpan(otelSpan: SpanData, defaultLocalEndpoint: ZipkinEndpoint, useShortTraceIds: Bool = false) -> ZipkinSpan {
        let parentId = otelSpan.parentSpanId.hexString

        var attributeEnumerationState = AttributeEnumerationState()

        otelSpan.attributes.forEach {
            processAttributes(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        otelSpan.resource.attributes.forEach {
            processResources(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        var localEndpoint = defaultLocalEndpoint

        if let serviceName = attributeEnumerationState.serviceName, !serviceName.isEmpty {
            if localEndpointCache[serviceName] == nil {
                localEndpoint = defaultLocalEndpoint.clone(serviceName: serviceName)
                localEndpointCache[serviceName] = localEndpoint
            }
        }
        
        if let serviceNamespace = attributeEnumerationState.serviceNamespace, !serviceNamespace.isEmpty {
            attributeEnumerationState.tags["service.namespace"] = serviceNamespace
        }

        var remoteEndpoint: ZipkinEndpoint?
        if (otelSpan.kind == .client || otelSpan.kind == .producer) && attributeEnumerationState.RemoteEndpointServiceName != nil {
            remoteEndpoint = remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!]
            if remoteEndpoint == nil {
                remoteEndpoint = ZipkinEndpoint(serviceName: attributeEnumerationState.RemoteEndpointServiceName!)
                remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!] = remoteEndpoint!
            }
        }

        let status = otelSpan.status

        if status?.isOk ?? false {
            attributeEnumerationState.tags[statusCode] = "\(status!.canonicalCode)".capitalized
            if status?.statusDescription != nil {
                attributeEnumerationState.tags[statusDescription] = status!.description
            }
        }

        let annotations = otelSpan.timedEvents.map { processEvents(event: $0) }

        return ZipkinSpan(traceId: ZipkinConversionExtension.EncodeTraceId(traceId: otelSpan.traceId, useShortTraceIds: useShortTraceIds),
                          parentId: parentId,
                          id: ZipkinConversionExtension.EncodeSpanId(spanId: otelSpan.spanId),
                          kind: ZipkinConversionExtension.toSpanKind(otelSpan: otelSpan),
                          name: otelSpan.name,
                          timestamp: otelSpan.startEpochNanos / 1000,
                          duration: ( otelSpan.endEpochNanos - otelSpan.startEpochNanos) * 1000000,
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
            return String(format: "%016llx", traceId.lowerLong)
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

    private static func processEvents(event: TimedEvent) -> ZipkinAnnotation {
        return ZipkinAnnotation(timestamp: event.epochNanos / 1000, value: event.name)
    }

    private static func processAttributes(state: inout AttributeEnumerationState, key: String, value: AttributeValue) {
        if case let .string(val) = value,
            let priority = remoteEndpointServiceNameKeyResolution[key] {
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
            if key == ResourceConstants.serviceName {
                state.serviceName = val
            } else if key == ResourceConstants.serviceNamespace {
                state.serviceNamespace = val
            } else {
                state.tags[key] = val
            }
        } else {
            state.tags[key] = value.description
        }
    }
}
