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
  static let defaultServiceName = "HackerNewsDemo"
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

  static let defaultTracesEndpoint = collectorBaseURL.appendingPathComponent("v1/traces")
  static let defaultLogsEndpoint = collectorBaseURL.appendingPathComponent("v1/logs")

  // Values edited in Settings win over the defaults, except in integration
  // test mode where the runner controls the endpoints. Like the session
  // config, they are read once at startup.
  static var serviceName: String {
    IntegrationTestScenario.isEnabled ? defaultServiceName : (OTelConfigStore.serviceName ?? defaultServiceName)
  }

  static var tracesEndpoint: URL {
    IntegrationTestScenario.isEnabled ? defaultTracesEndpoint : (OTelConfigStore.tracesEndpoint ?? defaultTracesEndpoint)
  }

  static var logsEndpoint: URL {
    IntegrationTestScenario.isEnabled ? defaultLogsEndpoint : (OTelConfigStore.logsEndpoint ?? defaultLogsEndpoint)
  }
  static let defaultSessionTimeout: TimeInterval = 300

  // The session config is only read when the SessionManager is created and the
  // span/log processors keep the manager they were built with, so edits made
  // in Settings are persisted by SessionConfigStore and applied on next launch.
  static var sessionConfig: SessionConfig {
    IntegrationTestScenario.isEnabled ? IntegrationTestScenario.sessionConfig : SessionConfigStore.load()
  }
}

enum Telemetry {
  nonisolated(unsafe) private static var urlSessionInstrumentation: URLSessionInstrumentation?

  static func start() {
    let resource = DefaultResources().get().merging(other: Resource(attributes: [
      ResourceAttributes.serviceName.rawValue: .string(TelemetryConfig.serviceName),
      ResourceAttributes.serviceVersion.rawValue: .string(TelemetryConfig.serviceVersion)
    ]))

    SessionManagerProvider.register(sessionManager: SessionManager(configuration: TelemetryConfig.sessionConfig))

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

// Exporter settings edited from the Settings tab. nil means "use the default".
enum OTelConfigStore {
  private static let serviceNameKey = "HackerNewsDemo.otel.serviceName"
  private static let tracesEndpointKey = "HackerNewsDemo.otel.tracesEndpoint"
  private static let logsEndpointKey = "HackerNewsDemo.otel.logsEndpoint"

  static var serviceName: String? {
    get { nonEmpty(UserDefaults.standard.string(forKey: serviceNameKey)) }
    set { UserDefaults.standard.set(nonEmpty(newValue), forKey: serviceNameKey) }
  }

  static var tracesEndpoint: URL? {
    get { url(forKey: tracesEndpointKey) }
    set { UserDefaults.standard.set(newValue?.absoluteString, forKey: tracesEndpointKey) }
  }

  static var logsEndpoint: URL? {
    get { url(forKey: logsEndpointKey) }
    set { UserDefaults.standard.set(newValue?.absoluteString, forKey: logsEndpointKey) }
  }

  static func reset() {
    [serviceNameKey, tracesEndpointKey, logsEndpointKey].forEach {
      UserDefaults.standard.removeObject(forKey: $0)
    }
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }

  private static func url(forKey key: String) -> URL? {
    nonEmpty(UserDefaults.standard.string(forKey: key)).flatMap(URL.init(string:))
  }
}

// Session settings edited from the Settings tab. Read once at startup by
// TelemetryConfig.sessionConfig.
enum SessionConfigStore {
  private static let timeoutKey = "HackerNewsDemo.session.timeout"
  private static let maxLifetimeKey = "HackerNewsDemo.session.maxLifetime"
  private static let restoreKey = "HackerNewsDemo.session.restorePersistedSession"

  static func load() -> SessionConfig {
    let defaults = UserDefaults.standard
    let builder = SessionConfig.builder()
    let timeout = defaults.double(forKey: timeoutKey)
    builder.with(sessionTimeout: timeout > 0 ? timeout : TelemetryConfig.defaultSessionTimeout)
    let maxLifetime = defaults.double(forKey: maxLifetimeKey)
    builder.with(maxLifetime: maxLifetime > 0 ? maxLifetime : nil)
    if defaults.object(forKey: restoreKey) != nil {
      builder.with(restorePersistedSession: defaults.bool(forKey: restoreKey))
    }
    return builder.build()
  }

  static func save(sessionTimeout: TimeInterval, maxLifetime: TimeInterval?, restorePersistedSession: Bool) {
    let defaults = UserDefaults.standard
    defaults.set(sessionTimeout, forKey: timeoutKey)
    if let maxLifetime {
      defaults.set(maxLifetime, forKey: maxLifetimeKey)
    } else {
      defaults.removeObject(forKey: maxLifetimeKey)
    }
    defaults.set(restorePersistedSession, forKey: restoreKey)
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
