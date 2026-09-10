/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import Sessions
import URLSessionInstrumentation

enum TelemetryConfig {
  static let serviceName = "HackerNewsDemo"
  static let serviceVersion = "1.0.0"
  static let tracesEndpoint = URL(string: "http://localhost:4318/v1/traces")!
  static let logsEndpoint = URL(string: "http://localhost:4318/v1/logs")!
  static let sessionTimeout: TimeInterval = 300
}

enum Telemetry {
  nonisolated(unsafe) private static var urlSessionInstrumentation: URLSessionInstrumentation?

  static func start() {
    let resource = DefaultResources().get().merging(other: Resource(attributes: [
      ResourceAttributes.serviceName.rawValue: .string(TelemetryConfig.serviceName),
      ResourceAttributes.serviceVersion.rawValue: .string(TelemetryConfig.serviceVersion)
    ]))

    let sessionConfig = SessionConfig.builder()
      .with(sessionTimeout: TelemetryConfig.sessionTimeout)
      .build()
    SessionManagerProvider.register(sessionManager: SessionManager(configuration: sessionConfig))

    let spanExporter = OtlpHttpTraceExporter(endpoint: TelemetryConfig.tracesEndpoint)
    OpenTelemetry.registerTracerProvider(tracerProvider:
      TracerProviderBuilder()
        .with(resource: resource)
        .add(spanProcessor: SessionSpanProcessor())
        .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
        .build()
    )

    let logExporter = OtlpHttpLogExporter(endpoint: TelemetryConfig.logsEndpoint)
    OpenTelemetry.registerLoggerProvider(loggerProvider:
      LoggerProviderBuilder()
        .with(resource: resource)
        .with(processors: [
          SessionLogRecordProcessor(nextProcessor: BatchLogRecordProcessor(logRecordExporter: logExporter))
        ])
        .build()
    )

    SessionEventInstrumentation.install()

    urlSessionInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())

    // TODO: no app startup instrumentation
    // TODO: no crash instrumentation; MetricKit sources exist under
    //       Sources/Instrumentation/MetricKit but are not exposed as a package product yet
    // TODO: no app hang instrumentation
    // TODO: no UIKit/SwiftUI view instrumentation
    // TODO: no user ID manager; see UserIdStore
  }
}

// TODO: stand-in until a user ID instrumentation exists.
// This only persists the value; nothing attaches it to telemetry.
enum UserIdStore {
  private static let key = "HackerNewsDemo.userId"

  static func getUID() -> String {
    UserDefaults.standard.string(forKey: key) ?? "nil"
  }

  static func setUID(_ uid: String) {
    UserDefaults.standard.set(uid, forKey: key)
  }
}
