/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

/// Represents the complete payload sent to Faro collector
struct FaroPayload: Encodable {
  let meta: FaroMeta
  let traces: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest?
  let logs: [FaroLog]?
  let events: [FaroEvent]?
  let measurements: [FaroMeasurement]?
  let exceptions: [FaroException]?

  init(meta: FaroMeta,
       traces: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest? = nil,
       logs: [FaroLog]? = nil,
       events: [FaroEvent]? = nil,
       measurements: [FaroMeasurement]? = nil,
       exceptions: [FaroException]? = nil) {
    self.meta = meta
    self.traces = traces
    self.logs = logs
    self.events = events
    self.measurements = measurements
    self.exceptions = exceptions
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(meta, forKey: .meta)

    if let traces {
      let jsonData = try traces.jsonUTF8Data()
      let jsonString = String(data: jsonData, encoding: .utf8)
      try container.encode(jsonString, forKey: .traces)
    }

    if let logs {
      try container.encode(logs, forKey: .logs)
    }

    if let events {
      try container.encode(events, forKey: .events)
    }

    if let measurements {
      try container.encode(measurements, forKey: .measurements)
    }

    if let exceptions {
      try container.encode(exceptions, forKey: .exceptions)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case meta
    case traces
    case logs
    case events
    case measurements
    case exceptions
  }
}

/// Holds metadata about an app event
struct FaroMeta: Encodable {
  let sdk: FaroSdkInfo
  let app: FaroAppInfo
  let session: FaroSession
  let user: FaroUser?
  let view: FaroView

  init(sdk: FaroSdkInfo, app: FaroAppInfo, session: FaroSession, user: FaroUser?, view: FaroView) {
    self.sdk = sdk
    self.app = app
    self.session = session
    self.user = user
    self.view = view
  }
}

/// Holds metadata about a view
struct FaroView: Encodable {
  let name: String

  init(name: String) {
    self.name = name
  }
}

/// Holds metadata about the user related to an app event
struct FaroUser: Encodable {
  let id: String?
  let username: String?
  let email: String?
  let attributes: [String: String]

  init(id: String, username: String, email: String, attributes: [String: String]) {
    self.id = id
    self.username = username
    self.email = email
    self.attributes = attributes
  }
}

/// Holds metadata about the browser session the event originates from
struct FaroSession: Encodable {
  let id: String
  let attributes: [String: String]

  init(id: String, attributes: [String: String]) {
    self.id = id
    self.attributes = attributes
  }
}

/// Holds metadata about the app agent that produced the event
struct FaroSdkInfo: Encodable {
  let name: String
  let version: String
  let integrations: [FaroIntegration]

  init(name: String, version: String, integrations: [FaroIntegration]) {
    self.name = name
    self.version = version
    self.integrations = integrations
  }
}

/// Holds metadata about a plugin/integration on the app agent that collected and sent the event
struct FaroIntegration: Encodable {
  let name: String
  let version: String

  init(name: String, version: String) {
    self.name = name
    self.version = version
  }
}

/// Holds metadata about the application event originates from
struct FaroAppInfo: Encodable {
  let name: String?
  let namespace: String?
  let version: String?
  let environment: String?
  let bundleId: String?
  let release: String?

  init(name: String?, namespace: String?, version: String?, environment: String?, bundleId: String?, release: String?) {
    self.name = name
    self.namespace = namespace
    self.version = version
    self.environment = environment
    self.bundleId = bundleId
    self.release = release
  }
}

/// Holds trace id and span id associated to an entity (log, exception, measurement...)
struct FaroTraceContext: Encodable, Equatable {
  let traceId: String?
  let spanId: String?

  enum CodingKeys: String, CodingKey {
    case traceId = "trace_id"
    case spanId = "span_id"
  }

  private init(traceId: String?, spanId: String?) {
    self.traceId = traceId
    self.spanId = spanId
  }

  static func create(traceId: String?, spanId: String?) -> FaroTraceContext? {
    guard traceId?.isEmpty == false || spanId?.isEmpty == false else {
      return nil
    }
    return FaroTraceContext(traceId: traceId, spanId: spanId)
  }
}

/// Holds RUM event data
struct FaroEvent: Encodable {
  let name: String
  let domain: String
  let attributes: [String: String]
  let timestamp: String
  let trace: FaroTraceContext?

  init(name: String,
       attributes: [String: String],
       timestamp: String,
       trace: FaroTraceContext?) {
    self.name = name
    domain = "swift"
    self.attributes = attributes
    self.timestamp = timestamp
    self.trace = trace
  }
}

/// Holds the data for user provided measurements
struct FaroMeasurement: Encodable {
  let type: String
  let values: [String: Double]
  let timestamp: String
  let trace: FaroTraceContext?

  init(type: String, values: [String: Double], timestamp: String, trace: FaroTraceContext?) {
    self.type = type
    self.values = values
    self.timestamp = timestamp
    self.trace = trace
  }
}

/// Represents a single stacktrace frame
struct FaroStacktraceFrame: Encodable {
  let colno: Int
  let lineno: Int
  let filename: String
  let function: String
  let module: String

  init(colno: Int, lineno: Int, filename: String, function: String, module: String) {
    self.colno = colno
    self.lineno = lineno
    self.filename = filename
    self.function = function
    self.module = module
  }
}

/// Is a collection of Frames
struct FaroStacktrace: Encodable {
  let frames: [FaroStacktraceFrame]

  init(frames: [FaroStacktraceFrame]) {
    self.frames = frames
  }
}

/// Holds all the data regarding an exception
struct FaroException: Encodable {
  let type: String
  let value: String
  let timestamp: String
  let stacktrace: FaroStacktrace?
  let context: [String: String]?
  let trace: FaroTraceContext?

  init(type: String, value: String, timestamp: String, stacktrace: FaroStacktrace?, context: [String: String]?, trace: FaroTraceContext?) {
    self.type = type
    self.value = value
    self.timestamp = timestamp
    self.stacktrace = stacktrace
    self.context = context
    self.trace = trace
  }
}

/// Log level enum for incoming app logs
enum FaroLogLevel: String, Encodable {
  case trace
  case debug
  case info
  case warning
  case error
}

/// Controls the data that come into a Log message
struct FaroLog: Encodable, Equatable {
  let timestamp: String
  let level: FaroLogLevel
  let message: String
  let context: [String: String]?
  let trace: FaroTraceContext?

  init(timestamp: String, level: FaroLogLevel, message: String, context: [String: String]?, trace: FaroTraceContext?) {
    self.timestamp = timestamp
    self.level = level
    self.message = message
    self.context = context
    self.trace = trace
  }
}

/// Error types used throughout the exporter
enum FaroExporterError: Error, Equatable {
  case invalidCollectorUrl
  case missingApiKey
  case payloadTooLarge
  case networkError(Error)
  case serializationError(Error)

  static func == (lhs: FaroExporterError, rhs: FaroExporterError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidCollectorUrl, .invalidCollectorUrl),
         (.missingApiKey, .missingApiKey),
         (.payloadTooLarge, .payloadTooLarge):
      return true
    case let (.networkError(lhsError), .networkError(rhsError)):
      return lhsError.localizedDescription == rhsError.localizedDescription
    case let (.serializationError(lhsError), .serializationError(rhsError)):
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}
