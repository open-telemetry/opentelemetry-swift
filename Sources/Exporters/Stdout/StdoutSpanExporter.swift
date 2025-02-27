/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

@available(*, deprecated, renamed: "StdoutSpanExporter")
public typealias StdoutExporter = StdoutSpanExporter

public class StdoutSpanExporter: SpanExporter {
  let isDebug: Bool

  public init(isDebug: Bool = false) {
    self.isDebug = isDebug
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    let jsonEncoder = JSONEncoder()
    for span in spans {
      if isDebug {
        print("__________________")
        print("Span \(span.name):")
        print("TraceId: \(span.traceId.hexString)")
        print("SpanId: \(span.spanId.hexString)")
        print("Span kind: \(span.kind.rawValue)")
        print("TraceFlags: \(span.traceFlags)")
        print("TraceState: \(span.traceState)")
        print("ParentSpanId: \(span.parentSpanId?.hexString ?? SpanId.invalid.hexString)")
        print("Start: \(span.startTime.timeIntervalSince1970.toNanoseconds)")
        print("Duration: \(span.endTime.timeIntervalSince(span.startTime).toNanoseconds) nanoseconds")
        print("Attributes: \(span.attributes)")
        if !span.events.isEmpty {
          print("Events:")
          for event in span.events {
            let ts = event.timestamp.timeIntervalSince(span.startTime).toNanoseconds
            print("  \(event.name) Time: +\(ts) Attributes: \(event.attributes)")
          }
        }
        print("------------------\n")
      } else {
        do {
          let jsonData = try jsonEncoder.encode(SpanExporterData(span: span))
          if let json = String(data: jsonData, encoding: .utf8) {
            print(json)
          }
        } catch {
          return .failure
        }
      }
    }
    return .success
  }

  public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval?) {}
}

private struct SpanExporterData {
  private let span: String
  private let traceId: String
  private let spanId: String
  private let spanKind: String
  private let traceFlags: TraceFlags
  private let traceState: TraceState
  private let parentSpanId: String?
  private let start: Date
  private let duration: TimeInterval
  private let attributes: [String: AttributeValue]

  init(span: SpanData) {
    self.span = span.name
    traceId = span.traceId.hexString
    spanId = span.spanId.hexString
    spanKind = span.kind.rawValue
    traceFlags = span.traceFlags
    traceState = span.traceState
    parentSpanId = span.parentSpanId?.hexString ?? SpanId.invalid.hexString
    start = span.startTime
    duration = span.endTime.timeIntervalSince(span.startTime)
    attributes = span.attributes
  }
}

extension SpanExporterData: Encodable {
  enum CodingKeys: String, CodingKey {
    case span
    case traceId
    case spanId
    case spanKind
    case traceFlags
    case traceState
    case parentSpanId
    case start
    case duration
    case attributes
  }

  enum TraceFlagsCodingKeys: String, CodingKey {
    case sampled
  }

  enum TraceStateCodingKeys: String, CodingKey {
    case entries
  }

  enum TraceStateEntryCodingKeys: String, CodingKey {
    case key
    case value
  }

  struct AttributesCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(intValue: Int) {
      stringValue = "\(intValue)"
      self.intValue = intValue
    }

    init?(stringValue: String) {
      self.stringValue = stringValue
    }
  }

  enum AttributeValueCodingKeys: String, CodingKey {
    case description
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(span, forKey: .span)
    try container.encode(traceId, forKey: .traceId)
    try container.encode(spanId, forKey: .spanId)
    try container.encode(spanKind, forKey: .spanKind)

    var traceFlagsContainer = container.nestedContainer(keyedBy: TraceFlagsCodingKeys.self, forKey: .traceFlags)
    try traceFlagsContainer.encode(traceFlags.sampled, forKey: .sampled)

    var traceStateContainer = container.nestedContainer(keyedBy: TraceStateCodingKeys.self, forKey: .traceState)
    var traceStateEntriesContainer = traceStateContainer.nestedUnkeyedContainer(forKey: .entries)

    try traceState.entries.forEach { entry in
      var traceStateEntryContainer = traceStateEntriesContainer.nestedContainer(keyedBy: TraceStateEntryCodingKeys.self)

      try traceStateEntryContainer.encode(entry.key, forKey: .key)
      try traceStateEntryContainer.encode(entry.value, forKey: .value)
    }

    try container.encodeIfPresent(parentSpanId, forKey: .parentSpanId)
    try container.encode(start, forKey: .start)
    try container.encode(duration, forKey: .duration)

    var attributesContainer = container.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .attributes)

    try attributes.forEach { attribute in

      if let attributeValueCodingKey = AttributesCodingKeys(stringValue: attribute.key) {
        var attributeValueContainer = attributesContainer.nestedContainer(keyedBy: AttributeValueCodingKeys.self, forKey: attributeValueCodingKey)

        try attributeValueContainer.encode(attribute.value.description, forKey: .description)
      } else {
        // this should never happen
        let encodingContext = EncodingError.Context(codingPath: attributesContainer.codingPath,
                                                    debugDescription: "Failed to create coding key")

        throw EncodingError.invalidValue(attribute, encodingContext)
      }
    }
  }
}
