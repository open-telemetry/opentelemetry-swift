/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

  import Foundation
  import OpenTelemetryApi
  import OpenTelemetrySdk
  import Thrift

  final class Adapter {
    static let keyError = "error"
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
      let traceIdHigh = Int64(traceHex[traceHex.startIndex..<secondIndex], radix: 16) ?? 0
      let traceIdLow = Int64(traceHex[secondIndex..<traceHex.endIndex], radix: 16) ?? 0

      let spanHex = span.spanId.hexString
      let spanId = Int64(spanHex, radix: 16) ?? 0
      let operationName = span.name
      let startTime = Int64(span.startTime.timeIntervalSince1970.toMicroseconds)
      let duration = Int64(span.endTime.timeIntervalSince(span.startTime).toMicroseconds)

      var parentSpanId: Int64 = 0

      tags.append(contentsOf: toJaegerTags(attributes: span.attributes))
      logs.append(contentsOf: toJaegerLogs(events: span.events))
      references.append(contentsOf: toSpanRefs(links: span.links))

      if let parentId = span.parentSpanId, parentId.isValid {
        let parentTraceIdHigh = traceIdHigh
        let parentTraceIdLow = traceIdLow

        let spanHex = parentId.hexString
        parentSpanId = Int64(spanHex, radix: 16) ?? 0

        let refType = SpanRefType.child_of
        let spanRef = SpanRef(
          refType: refType, traceIdLow: parentTraceIdLow, traceIdHigh: parentTraceIdHigh,
          spanId: parentSpanId)

        references.append(spanRef)
      }

      tags.append(
        Tag(
          key: Adapter.keySpanKind, vType: .string, vStr: span.kind.rawValue.uppercased(),
          vDouble: nil, vBool: nil, vLong: nil, vBinary: nil))
      if case let Status.error(description) = span.status {
        tags.append(
          Tag(
            key: Adapter.keySpanStatusMessage, vType: .string, vStr: description, vDouble: nil,
            vBool: nil, vLong: nil, vBinary: nil))
        tags.append(
          Tag(
            key: keyError, vType: .bool, vStr: nil, vDouble: nil, vBool: true, vLong: nil,
            vBinary: nil))

      } else {
        tags.append(
          Tag(
            key: Adapter.keySpanStatusMessage, vType: .string, vStr: "", vDouble: nil, vBool: nil,
            vLong: nil, vBinary: nil))
      }
      tags.append(
        Tag(
          key: Adapter.keySpanStatusCode, vType: .long, vStr: nil, vDouble: nil, vBool: nil,
          vLong: Int64(span.status.code), vBinary: nil))

      return Span(
        traceIdLow: traceIdLow, traceIdHigh: traceIdHigh, spanId: spanId,
        parentSpanId: parentSpanId, operationName: operationName, references: references, flags: 0,
        startTime: startTime, duration: duration, tags: tags, logs: logs)
    }

    static func toJaegerTags(attributes: [String: AttributeValue]) -> [Tag] {
      var tags = [Tag]()
      tags.reserveCapacity(attributes.count)
      attributes.forEach {
        tags.append(toJaegerTag(key: $0.key, attrib: $0.value))
      }
      return tags
    }

    
    static func processAttributeArray(data: AttributeArray) -> [String] {
      var processedValues = [String]()
      data.values.forEach { item in
        switch item {
        case let .string(value):
          processedValues.append("\"\(value)\"")
        case let .bool(value):
          processedValues.append(value.description)
        case let .int(value):
          processedValues.append(Int64(value).description)
        case let .double(value):
          processedValues.append(value.description)
        case let .array(value):
          let array = processAttributeArray(data: value)
          if let json = try? String(data: JSONEncoder().encode(array), encoding: .utf8) {
            processedValues.append(json)
          }
        case let .set(value):
          if let json = try? String(data: JSONEncoder().encode(value), encoding: .utf8) {
            processedValues.append(json)
          }
        case let .stringArray(value):
          if let json = try? String(data: JSONEncoder().encode(value), encoding: .utf8) {
            processedValues.append(json)
          }
        case let .boolArray(value):
          if let json = try? String(data: JSONEncoder().encode(value), encoding: .utf8) {
            processedValues.append(json)
          }
        case let .intArray(value):
          if let json = try? String(data: JSONEncoder().encode(value), encoding: .utf8) {
            processedValues.append(json)
          }
        case let .doubleArray(value):
          if let json = try? String(data: JSONEncoder().encode(value), encoding: .utf8) {
            processedValues.append(json)
          }
        }
      }
      return processedValues
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
      case let .stringArray(value):
        vType = .string
        vStr = try? String(data: JSONEncoder().encode(value), encoding: .utf8)
      case let .boolArray(value):
        vType = .string
        vStr = try? String(data: JSONEncoder().encode(value), encoding: .utf8)
      case let .intArray(value):
        vType = .string
        vStr = try? String(data: JSONEncoder().encode(value), encoding: .utf8)
      case let .doubleArray(value):
        vType = .string
        vStr = try? String(data: JSONEncoder().encode(value), encoding: .utf8)
      case let .array(value):
        vType = .string
        vStr = "[\(processAttributeArray(data: value).joined(separator: ", "))]"
      case let .set(value):
        vType = .string
        vStr = try? String(data: JSONEncoder().encode(value), encoding: .utf8)
      }
      return Tag(
        key: key, vType: vType, vStr: vStr, vDouble: vDouble, vBool: vBool, vLong: vLong,
        vBinary: nil)
    }

    static func toJaegerLogs(events: [SpanData.Event]) -> [Log] {
      var logs = [Log]()
      logs.reserveCapacity(events.count)

      events.forEach {
        logs.append(toJaegerLog(event: $0))
      }
      return logs
    }

    static func toJaegerLog(event: SpanData.Event) -> Log {
      let timestamp = Int64(event.timestamp.timeIntervalSince1970.toMicroseconds)

      var tags = TList<Tag>()
      tags.append(
        Tag(
          key: Adapter.keyLogMessage, vType: .string, vStr: event.name, vDouble: nil, vBool: nil,
          vLong: nil, vBinary: nil))
      tags.append(contentsOf: toJaegerTags(attributes: event.attributes))
      return Log(timestamp: timestamp, fields: tags)
    }

    static func toSpanRefs(links: [SpanData.Link]) -> [SpanRef] {
      var spanRefs = [SpanRef]()
      spanRefs.reserveCapacity(links.count)
      links.forEach {
        spanRefs.append(toSpanRef(link: $0))
      }
      return spanRefs
    }

    static func toSpanRef(link: SpanData.Link) -> SpanRef {
      let traceHex = link.context.traceId.hexString
      let secondIndex = traceHex.index(traceHex.startIndex, offsetBy: 16)
      let traceIdHigh = Int64(traceHex[traceHex.startIndex..<secondIndex], radix: 16) ?? 0
      let traceIdLow = Int64(traceHex[secondIndex..<traceHex.endIndex], radix: 16) ?? 0

      let spanHex = link.context.spanId.hexString
      let spanId = Int64(spanHex, radix: 16) ?? 0
      let refType = SpanRefType.follows_from

      return SpanRef(
        refType: refType, traceIdLow: traceIdLow, traceIdHigh: traceIdHigh, spanId: spanId)
    }
  }

#endif
