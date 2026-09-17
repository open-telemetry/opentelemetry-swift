/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryProtocolExporterCommon
import SwiftProtobuf
import XCTest

typealias ProtoSpan = Opentelemetry_Proto_Trace_V1_Span
typealias ProtoLogRecord = Opentelemetry_Proto_Logs_V1_LogRecord
typealias ProtoScope = Opentelemetry_Proto_Common_V1_InstrumentationScope
typealias ProtoAttributes = [Opentelemetry_Proto_Common_V1_KeyValue]

// A span or log together with the resource and scope it was exported under.
struct ExportedSpan {
  let resource: ProtoAttributes
  let scope: ProtoScope
  let span: ProtoSpan
}

struct ExportedLog {
  let resource: ProtoAttributes
  let scope: ProtoScope
  let record: ProtoLogRecord
}

extension Array where Element == Opentelemetry_Proto_Common_V1_KeyValue {
  subscript(key: String) -> Opentelemetry_Proto_Common_V1_AnyValue? {
    first { $0.key == key }?.value
  }

  func string(_ key: String) -> String? {
    guard case let .stringValue(value)? = self[key]?.value else { return nil }
    return value
  }

  func int(_ key: String) -> Int64? {
    guard case let .intValue(value)? = self[key]?.value else { return nil }
    return value
  }
}

// Loads the files produced by a run of Scripts/run-integration-tests.sh: the
// OpenTelemetry Collector's `file` exporter in `proto` format, a stream of
// 4-byte big-endian length prefixes each followed by an
// Export<Signal>ServiceRequest. The base directory comes from
// OTEL_INTEGRATION_OUTPUT_DIR, defaulting to ./out next to this package. Each
// app launch of the run has its own subdirectory named after its launch tag;
// `OTLPOutput.main` is the primary launch.
struct OTLPOutput {
  static let outputDirectoryEnvironmentKey = "OTEL_INTEGRATION_OUTPUT_DIR"

  static let baseDirectory: URL = {
    if let path = ProcessInfo.processInfo.environment[outputDirectoryEnvironmentKey], !path.isEmpty {
      return URL(fileURLWithPath: path, isDirectory: true)
    }
    return URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("out", isDirectory: true)
  }()

  static let main = OTLPOutput(launch: Scenario.Launch.main)

  static func launch(_ launch: Scenario.Launch) -> OTLPOutput {
    OTLPOutput(launch: launch)
  }

  // Convenience accessors for the main launch, which most suites assert on.
  static var spans: [ExportedSpan] { main.spans }
  static var logs: [ExportedLog] { main.logs }

  let directory: URL

  private init(launch: Scenario.Launch) {
    directory = Self.baseDirectory.appendingPathComponent(launch.rawValue, isDirectory: true)
  }

  var spans: [ExportedSpan] {
    Self.decodeMessages(file: directory.appendingPathComponent("traces.pb"),
                        as: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.self)
      .flatMap { request in
        request.resourceSpans.flatMap { resourceSpans in
          resourceSpans.scopeSpans.flatMap { scopeSpans in
            scopeSpans.spans.map { ExportedSpan(resource: resourceSpans.resource.attributes, scope: scopeSpans.scope, span: $0) }
          }
        }
      }
  }

  var logs: [ExportedLog] {
    Self.decodeMessages(file: directory.appendingPathComponent("logs.pb"),
                        as: Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.self)
      .flatMap { request in
        request.resourceLogs.flatMap { resourceLogs in
          resourceLogs.scopeLogs.flatMap { scopeLogs in
            scopeLogs.logRecords.map { ExportedLog(resource: resourceLogs.resource.attributes, scope: scopeLogs.scope, record: $0) }
          }
        }
      }
  }

  private static func decodeMessages<M: SwiftProtobuf.Message>(file url: URL, as type: M.Type) -> [M] {
    guard let data = try? Data(contentsOf: url) else {
      print("[IntegrationTests] missing \(url.path); run Scripts/run-integration-tests.sh first")
      return []
    }
    var messages: [M] = []
    var offset = data.startIndex
    while offset + 4 <= data.endIndex {
      let length = data[offset ..< offset + 4].reduce(0) { Int($0) << 8 | Int($1) }
      offset += 4
      guard offset + length <= data.endIndex else {
        print("[IntegrationTests] truncated message in \(url.lastPathComponent)")
        break
      }
      do {
        messages.append(try M(serializedBytes: data[offset ..< offset + length]))
      } catch {
        print("[IntegrationTests] could not decode message in \(url.lastPathComponent): \(error)")
      }
      offset += length
    }
    return messages
  }
}
