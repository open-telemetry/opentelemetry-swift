/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

// Deliberately loose Codable mirror of the OTLP proto JSON mapping. Every field
// is optional so the files written by OTLPMockCollector (SwiftProtobuf JSON) and
// by the collector's `file` exporter (pdata JSON, hex ids) both decode.
// Integers are strings on the wire in both encodings.

struct OTLPAttributeValue: Decodable {
  var stringValue: String?
  var intValue: String?
  var boolValue: Bool?
  var doubleValue: Double?
  var arrayValue: OTLPArrayValue?
}

struct OTLPArrayValue: Decodable {
  var values: [OTLPAttributeValue]?
}

struct OTLPKeyValue: Decodable {
  var key: String
  var value: OTLPAttributeValue
}

extension Array where Element == OTLPKeyValue {
  subscript(key: String) -> OTLPAttributeValue? {
    first { $0.key == key }?.value
  }

  func string(_ key: String) -> String? { self[key]?.stringValue }
  func int(_ key: String) -> Int? { self[key]?.intValue.flatMap(Int.init) }
}

struct OTLPResource: Decodable {
  var attributes: [OTLPKeyValue]?
}

struct OTLPScope: Decodable {
  var name: String?
  var version: String?
}

struct OTLPStatus: Decodable {
  var code: String?
  var message: String?
}

struct OTLPEvent: Decodable {
  var name: String?
  var attributes: [OTLPKeyValue]?
}

struct OTLPSpan: Decodable {
  var traceId: String?
  var spanId: String?
  var parentSpanId: String?
  var name: String?
  var kind: String?
  var startTimeUnixNano: String?
  var endTimeUnixNano: String?
  var attributes: [OTLPKeyValue]?
  var events: [OTLPEvent]?
  var status: OTLPStatus?
}

struct OTLPScopeSpans: Decodable {
  var scope: OTLPScope?
  var spans: [OTLPSpan]?
}

struct OTLPResourceSpans: Decodable {
  var resource: OTLPResource?
  var scopeSpans: [OTLPScopeSpans]?
}

struct OTLPTracesRequest: Decodable {
  var resourceSpans: [OTLPResourceSpans]?
}

struct OTLPLogRecord: Decodable {
  var timeUnixNano: String?
  var severityText: String?
  var severityNumber: String?
  var eventName: String?
  var body: OTLPAttributeValue?
  var attributes: [OTLPKeyValue]?
  var traceId: String?
  var spanId: String?
}

struct OTLPScopeLogs: Decodable {
  var scope: OTLPScope?
  var logRecords: [OTLPLogRecord]?
}

struct OTLPResourceLogs: Decodable {
  var resource: OTLPResource?
  var scopeLogs: [OTLPScopeLogs]?
}

struct OTLPLogsRequest: Decodable {
  var resourceLogs: [OTLPResourceLogs]?
}

// Flattened views so assertions can reason about a span or log together with
// the resource and scope it was exported under.
struct ExportedSpan {
  let resource: [OTLPKeyValue]
  let scope: OTLPScope
  let span: OTLPSpan
}

struct ExportedLog {
  let resource: [OTLPKeyValue]
  let scope: OTLPScope
  let record: OTLPLogRecord
}
