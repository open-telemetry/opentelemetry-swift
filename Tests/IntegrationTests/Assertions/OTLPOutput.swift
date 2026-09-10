/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest

// Loads the JSON lines files produced by a run of Scripts/run-integration-tests.sh.
// The directory comes from OTEL_INTEGRATION_OUTPUT_DIR, defaulting to ./out next
// to this package.
enum OTLPOutput {
  static let outputDirectoryEnvironmentKey = "OTEL_INTEGRATION_OUTPUT_DIR"

  static let directory: URL = {
    if let path = ProcessInfo.processInfo.environment[outputDirectoryEnvironmentKey], !path.isEmpty {
      return URL(fileURLWithPath: path, isDirectory: true)
    }
    return URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("out", isDirectory: true)
  }()

  static let spans: [ExportedSpan] = {
    decodeLines(file: "traces.jsonl", as: OTLPTracesRequest.self).flatMap { request in
      (request.resourceSpans ?? []).flatMap { resourceSpans in
        (resourceSpans.scopeSpans ?? []).flatMap { scopeSpans in
          (scopeSpans.spans ?? []).map { span in
            ExportedSpan(resource: resourceSpans.resource?.attributes ?? [],
                         scope: scopeSpans.scope ?? OTLPScope(),
                         span: span)
          }
        }
      }
    }
  }()

  static let logs: [ExportedLog] = {
    decodeLines(file: "logs.jsonl", as: OTLPLogsRequest.self).flatMap { request in
      (request.resourceLogs ?? []).flatMap { resourceLogs in
        (resourceLogs.scopeLogs ?? []).flatMap { scopeLogs in
          (scopeLogs.logRecords ?? []).map { record in
            ExportedLog(resource: resourceLogs.resource?.attributes ?? [],
                        scope: scopeLogs.scope ?? OTLPScope(),
                        record: record)
          }
        }
      }
    }
  }()

  private static func decodeLines<T: Decodable>(file: String, as type: T.Type) -> [T] {
    let url = directory.appendingPathComponent(file)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
      print("[IntegrationTests] missing \(url.path); run Scripts/run-integration-tests.sh first")
      return []
    }
    let decoder = JSONDecoder()
    return content.split(separator: "\n").compactMap { line in
      guard !line.isEmpty else { return nil }
      do {
        return try decoder.decode(type, from: Data(line.utf8))
      } catch {
        print("[IntegrationTests] could not decode line in \(file): \(error)")
        return nil
      }
    }
  }
}
