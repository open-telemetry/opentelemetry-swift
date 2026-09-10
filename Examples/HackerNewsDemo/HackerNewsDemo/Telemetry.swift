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
  // Overridable so the integration test runner can point the app at a
  // collector on a different port: `SIMCTL_CHILD_OTEL_EXPORTER_OTLP_ENDPOINT`.
  static let collectorBaseURL: URL = {
    if let value = ProcessInfo.processInfo.environment["OTEL_EXPORTER_OTLP_ENDPOINT"],
       let url = URL(string: value) {
      return url
    }
    return URL(string: "http://localhost:4318")!
  }()

  static let tracesEndpoint = collectorBaseURL.appendingPathComponent("v1/traces")
  static let logsEndpoint = collectorBaseURL.appendingPathComponent("v1/logs")
  static var sessionTimeout: TimeInterval {
    IntegrationTestScenario.isEnabled ? IntegrationTestScenario.sessionTimeout : 300
  }
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

    // Skip the exporter's own OTLP requests, otherwise every export produces
    // a span that triggers another export.
    urlSessionInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration(
      shouldInstrument: { request in
        guard let url = request.url else { return true }
        return url != TelemetryConfig.tracesEndpoint && url != TelemetryConfig.logsEndpoint
      }
    ))

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
