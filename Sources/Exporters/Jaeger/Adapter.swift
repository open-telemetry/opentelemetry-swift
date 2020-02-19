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
import Thrift

final class Adapter {
    static let keyLogMessage = "message"
    static let keySpanKind = "span.kind"
    static let keySpanStatusMessage = "span.status.message"
    static let keySpanStatusCode = "span.status.code"

    /// Converts a list of SpanData into a collection of Jaeger's Span.
    /// - Parameter spans: the list of spans to be converted
    static func toJaeger(spans: [SpanData]) -> [Span] {
        var converted = [Span]()
        converted.reserveCapacity(spans.count)
        spans.forEach {
            converted.append(toJaeger(span: $0))
        }
        return converted
    }

    /// Converts a single SpanData into a Jaeger's Span.
    /// - Parameter span: the span to be converted
    static func toJaeger(span: SpanData) -> Span {
        var tags = TList<Tag>()
        var logs = TList<Log>()
        var references = TList<SpanRef>()

        let traceHex = span.traceId.hexString
        let secondIndex = traceHex.index(traceHex.startIndex, offsetBy: 16)
        let traceIdHigh = Int64(traceHex[traceHex.startIndex ..< secondIndex], radix: 16) ?? 0
        let traceIdLow = Int64(traceHex[secondIndex ..< traceHex.endIndex], radix: 16) ?? 0

        let spanHex = span.spanId.hexString
        let spanId = Int64(spanHex, radix: 16) ?? 0
        let operationName = span.name
        let startTime = Int64(span.startEpochNanos / 1000)
        let duration = Int64((span.endEpochNanos - span.startEpochNanos) / 1000)

        var parentSpanId: Int64 = 0

        tags.append(contentsOf: toJaegerTags(attributes: span.attributes))
        logs.append(contentsOf: toJaegerLogs(timedEvents: span.timedEvents))
        references.append(contentsOf: toSpanRefs(links: span.links))

        if span.parentSpanId != nil {
            let parentTraceIdHigh = traceIdHigh
            let parentTraceIdLow = traceIdLow

            let spanHex = span.parentSpanId!.hexString
            parentSpanId = Int64(spanHex, radix: 16) ?? 0

            let refType = SpanRefType.child_of
            let spanRef = SpanRef(refType: refType, traceIdLow: parentTraceIdLow, traceIdHigh: parentTraceIdHigh, spanId: parentSpanId)

            references.append(spanRef)
        }

        tags.append(Tag(key: Adapter.keySpanKind, vType: .string, vStr: span.kind.rawValue.uppercased(), vDouble: nil, vBool: nil, vLong: nil, vBinary: nil))
        tags.append(Tag(key: Adapter.keySpanStatusMessage, vType: .string, vStr: span.status?.statusDescription ?? "", vDouble: nil, vBool: nil, vLong: nil, vBinary: nil))
        tags.append(Tag(key: Adapter.keySpanStatusCode, vType: .long, vStr: nil, vDouble: nil, vBool: nil, vLong: Int64(span.status?.canonicalCode.rawValue ?? 0), vBinary: nil))

        return Span(traceIdLow: traceIdLow, traceIdHigh: traceIdHigh, spanId: spanId, parentSpanId: parentSpanId, operationName: operationName, references: references, flags: 0, startTime: startTime, duration: duration, tags: tags, logs: logs)
    }

    static func toJaegerTags(attributes: [String: AttributeValue]) -> [Tag] {
        var tags = [Tag]()
        tags.reserveCapacity(attributes.count)
        attributes.forEach {
            tags.append(toJaegerTag(key: $0.key, attrib: $0.value))
        }
        return tags
    }

    static func toJaegerTag(key: String, attrib: AttributeValue) -> Tag {
        let key = key
        var vType: TagType
        var vStr: String?
        var vDouble: Double?
        var vBool: Bool?
        var vLong: Int64?

        switch attrib {
        case let .string(value):
            vType = .string
            vStr = value
        case let .bool(value):
            vType = .bool
            vBool = value
        case let .int(value):
            vType = .long
            vLong = Int64(value)
        case let .double(value):
            vType = .double
            vDouble = value
        }
        return Tag(key: key, vType: vType, vStr: vStr, vDouble: vDouble, vBool: vBool, vLong: vLong, vBinary: nil)
    }

    static func toJaegerLogs(timedEvents: [SpanData.TimedEvent]) -> [Log] {
        var logs = [Log]()
        logs.reserveCapacity(timedEvents.count)

        timedEvents.forEach {
            logs.append(toJaegerLog(timedEvent: $0))
        }
        return logs
    }

    static func toJaegerLog(timedEvent: SpanData.TimedEvent) -> Log {
        let timestamp = Int64(timedEvent.epochNanos * 1000)

        var tags = TList<Tag>()
        tags.append(Tag(key: Adapter.keyLogMessage, vType: .string, vStr: timedEvent.name, vDouble: nil, vBool: nil, vLong: nil, vBinary: nil))
        tags.append(contentsOf: toJaegerTags(attributes: timedEvent.attributes))
        return Log(timestamp: timestamp, fields: tags)
    }

    static func toSpanRefs(links: [Link]) -> [SpanRef] {
        var spanRefs = [SpanRef]()
        spanRefs.reserveCapacity(links.count)
        links.forEach {
            spanRefs.append(toSpanRef(link: $0))
        }
        return spanRefs
    }

    static func toSpanRef(link: Link) -> SpanRef {
        let traceHex = link.context.traceId.hexString
        let secondIndex = traceHex.index(traceHex.startIndex, offsetBy: 16)
        let traceIdHigh = Int64(traceHex[traceHex.startIndex ..< secondIndex], radix: 16) ?? 0
        let traceIdLow = Int64(traceHex[secondIndex ..< traceHex.endIndex], radix: 16) ?? 0

        let spanHex = link.context.spanId.hexString
        let spanId = Int64(spanHex, radix: 16) ?? 0
        let refType = SpanRefType.follows_from

        return SpanRef(refType: refType, traceIdLow: traceIdLow, traceIdHigh: traceIdHigh, spanId: spanId)
    }
}
