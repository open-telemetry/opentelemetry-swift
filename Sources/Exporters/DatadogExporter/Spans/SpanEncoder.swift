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

internal struct Constants {
    #if os(iOS)
    static let ddsource = "ios"
    #elseif os(tvOS)
    static let ddsource = "tvos"
    #elseif os(watchOS)
    static let ddsource = "watchos"
    #else
    static let ddsource = "macos"
    #endif
}

/// `SpanEnvelope` allows encoding multiple spans sharing the same `traceID` to a single payload.
internal struct SpanEnvelope: Encodable {
    enum CodingKeys: String, CodingKey {
        case spans
        case environment = "env"
    }

    let spans: [DDSpan]
    let environment: String

    /// The initializer to encode single `Span` within an envelope.
    init(span: DDSpan, environment: String) {
        self.init(spans: [span], environment: environment)
    }

    /// This initializer is `private` now, as we don't yet
    /// support batching multiple spans sharing the same `traceID` within a single payload.
    private init(spans: [DDSpan], environment: String) {
        self.spans = spans
        self.environment = environment
    }
}

/// `Encodable` representation of span.
internal struct DDSpan: Encodable {
    let traceID: TraceId
    let spanID: SpanId
    let parentID: SpanId?
    let name: String
    let serviceName: String
    let resource: String
    let startTime: UInt64
    let duration: UInt64
    let isError: Bool
    let errorMessage: String?
    let errorType: String?
    let errorStack: String?
    let type: String

    // MARK: - Meta

    let tracerVersion: String
    let applicationVersion: String
//    let networkConnectionInfo: NetworkConnectionInfo?
//    let mobileCarrierInfo: CarrierInfo?
//    let userInfo: UserInfo

    /// Custom tags, received from user
    let tags: [String: String]

    func encode(to encoder: Encoder) throws {
        try SpanEncoder().encode(self, to: encoder)
    }

    internal init(spanData: SpanData, configuration: ExporterConfiguration) {
        self.traceID = spanData.traceId
        self.spanID = spanData.spanId
        self.parentID = spanData.parentSpanId

        if let testType = spanData.attributes["test.type"] {
            self.name = "XCTest.\(testType.description)"
        } else {
            self.name = spanData.name + "." + spanData.kind.rawValue
        }

        self.serviceName = configuration.serviceName
        self.resource = spanData.name
        self.startTime = spanData.startEpochNanos
        self.duration = spanData.endEpochNanos - spanData.startEpochNanos

        if spanData.attributes["error"] != nil {
            self.isError = true
            self.errorMessage = spanData.attributes["error.msg"]?.description
            self.errorType = spanData.attributes["error.type"]?.description
            self.errorStack = spanData.attributes["error.stack"]?.description
        } else if !(spanData.status?.isOk ?? false) {
            self.isError = true
            self.errorMessage = spanData.status?.description ?? "error"
            self.errorType = spanData.status?.description ?? "error"
            self.errorStack = nil
        } else {
            self.isError = false
            self.errorMessage = nil
            self.errorType = nil
            self.errorStack = nil
        }

        let spanType = spanData.attributes["type"] ?? spanData.attributes["db.type"]
        self.type = spanType?.description ?? spanData.kind.rawValue

        self.tracerVersion = "1.0" // spanData.tracerVersion
        self.applicationVersion = "0.0.1" // spanData.applicationVersion
        self.tags = spanData.attributes.mapValues { $0.description }
    }
}

/// Encodes `SpanData` to given encoder.
internal struct SpanEncoder {
    /// Coding keys for permanent `Span` attributes.
    enum StaticCodingKeys: String, CodingKey {
        // MARK: - Attributes

        case traceID = "trace_id"
        case spanID = "span_id"
        case parentID = "parent_id"
        case name
        case service
        case resource
        case type
        case start
        case duration
        case isError = "error"

        // MARK: - Metrics

        case isRootSpan = "metrics._top_level"
        case samplingPriority = "metrics._sampling_priority_v1"

        // MARK: - Meta

        case source = "meta._dd.source"
        case applicationVersion = "meta.version"
        case tracerVersion = "meta.tracer.version"
    }

    /// Coding keys for dynamic `Span` attributes specified by user.
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
        init(_ string: String) { self.stringValue = string }
    }

    func encode(_ span: DDSpan, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StaticCodingKeys.self)
        try container.encode(String(format: "%016llx", span.traceID.rawLowerLong), forKey: .traceID)
        try container.encode(span.spanID.hexString, forKey: .spanID)

        let parentSpanID = span.parentID ?? SpanId.invalid // 0 is a reserved ID for a root span (ref: DDTracer.java#L600)
        try container.encode(parentSpanID.hexString, forKey: .parentID)

        try container.encode(span.name, forKey: .name)
        try container.encode(span.serviceName, forKey: .service)
        try container.encode(span.resource, forKey: .resource)
        try container.encode(span.type, forKey: .type)

        try container.encode(span.startTime, forKey: .start)
        try container.encode(span.duration, forKey: .duration)

        let isError = span.isError ? 1 : 0
        try container.encode(isError, forKey: .isError)

        try encodeDefaultMetrics(span, to: &container)
        try encodeDefaultMeta(span, to: &container)

        var customAttributesContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        try encodeCustomMeta(span, to: &customAttributesContainer)
    }

    /// Encodes default `metrics.*` attributes
    private func encodeDefaultMetrics(_ span: DDSpan, to container: inout KeyedEncodingContainer<StaticCodingKeys>) throws {
        // NOTE: RUMM-299 only numeric values are supported for `metrics.*` attributes
        if span.parentID == nil {
            try container.encode(1, forKey: .isRootSpan)
        }
        try container.encode(1, forKey: .samplingPriority)
    }

    /// Encodes default `meta.*` attributes
    private func encodeDefaultMeta(_ span: DDSpan, to container: inout KeyedEncodingContainer<StaticCodingKeys>) throws {
        // NOTE: RUMM-299 only string values are supported for `meta.*` attributes
        try container.encode(Constants.ddsource, forKey: .source)
        try container.encode(span.tracerVersion, forKey: .tracerVersion)
        try container.encode(span.applicationVersion, forKey: .applicationVersion)
    }

    /// Encodes `meta.*` attributes coming from user
    private func encodeCustomMeta(_ span: DDSpan, to container: inout KeyedEncodingContainer<DynamicCodingKey>) throws {
        // NOTE: RUMM-299 only string values are supported for `meta.*` attributes
        try span.tags.forEach {
            let metaKey = "meta.\($0.key)"
            try container.encode($0.value, forKey: DynamicCodingKey(metaKey))
        }
    }
}
