/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import MincoreLaunchInstrumentation
import Crash
import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import ResourceExtension
import ScreenInstrumentation
import ScreenInstrumentationUIKit
import Sessions
import UIKit
import URLSessionInstrumentation

enum TelemetryConfig {
  static let defaultServiceName = "HackerNewsDemo"
  static let serviceVersion = "1.0.0"

  /// Reads one OTLP setting by its standard name.
  ///
  /// The environment comes first, which is how the integration test runner
  /// points the app at a local collector:
  /// `SIMCTL_CHILD_OTEL_EXPORTER_OTLP_ENDPOINT`. A harness that drives a
  /// device it does not own, such as a cloud simulator, cannot set the
  /// environment of an app the system launches, so the launch arguments come
  /// second: iOS registers every `-name value` pair in `UserDefaults`.
  static func setting(_ name: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[name], !value.isEmpty {
      return value
    }
    guard let value = UserDefaults.standard.string(forKey: name), !value.isEmpty else {
      return nil
    }
    return value
  }

  static let collectorBaseURL: URL = {
    if let value = setting("OTEL_EXPORTER_OTLP_ENDPOINT"), let url = URL(string: value) {
      return url
    }
    return URL(string: "http://localhost:4318")!
  }()

  /// The headers every export carries, as `OTEL_EXPORTER_OTLP_HEADERS`. A
  /// hosted OTLP endpoint authenticates with them, so without them the
  /// exporters only reach a collector the app can trust.
  static let exporterHeaders: [(String, String)]? =
    EnvVarHeaders.attributes(for: setting("OTEL_EXPORTER_OTLP_HEADERS"))

  static let defaultTracesEndpoint = collectorBaseURL.appendingPathComponent("v1/traces")
  static let defaultLogsEndpoint = collectorBaseURL.appendingPathComponent("v1/logs")

  // Values edited in Settings win over the defaults, except in integration
  // test mode where the runner controls the endpoints. Like the session
  // config, they are read once at startup.
  static var serviceName: String {
    if IntegrationTestScenario.isEnabled { return defaultServiceName }
    return OTelConfigStore.serviceName ?? setting("OTEL_SERVICE_NAME") ?? defaultServiceName
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

  // The UIKit front end reads these at install, so edits made in Settings are persisted by
  // ScreenConfigStore and applied on next launch.
  static var screenConfig: ScreenConfigStore.Values {
    IntegrationTestScenario.isEnabled ? ScreenConfigStore.Values() : ScreenConfigStore.load()
  }

  static var screenTracker: ScreenTracker {
    ScreenTracker(recordsTimeToFirstDraw: screenConfig.recordsTimeToFirstDraw,
                  tracksNavigation: screenConfig.tracksNavigation)
  }

  static var screenUIKitConfig: ScreenUIKitConfig {
    let config = screenConfig
    return ScreenUIKitConfig(bundle: config.uikitBundle.bundle,
                             recordsTimeToFirstDraw: config.uikitRecordsTimeToFirstDraw.value,
                             tracksHostingControllers: config.tracksHostingControllers)
  }

  static var crashConfig: KSCrashInstrumentationConfig {
    IntegrationTestScenario.isEnabled ? IntegrationTestScenario.crashConfig : .default
  }

  // The demo itself keeps the instrumentation default; integration launches
  // choose it with `--httpSemanticConvention`.
  static var httpSemanticConvention: HTTPSemanticConvention {
    IntegrationTestScenario.isEnabled ? IntegrationTestScenario.httpSemanticConvention : .old
  }
}

enum Telemetry {
  nonisolated(unsafe) private static var urlSessionInstrumentation: URLSessionInstrumentation?

  @MainActor
  static func start() {
    OpenTelemetry.setDebugEnabled(true)

    let resource = DefaultResources().get().merging(other: Resource(attributes: [
      ResourceAttributes.serviceName.rawValue: .string(TelemetryConfig.serviceName),
      ResourceAttributes.serviceVersion.rawValue: .string(TelemetryConfig.serviceVersion)
    ]))

    SessionManagerProvider.register(sessionManager: SessionManager(configuration: TelemetryConfig.sessionConfig))

    // Captured once: endpoints edited in Settings only take effect on next
    // launch, so the exporters and the instrumentation filter must agree on
    // the URLs in use now.
    let tracesEndpoint = TelemetryConfig.tracesEndpoint
    let logsEndpoint = TelemetryConfig.logsEndpoint

    let screenConfig = TelemetryConfig.screenConfig
    let spanExporter = OtlpHttpTraceExporter(endpoint: tracesEndpoint,
                                             envVarHeaders: TelemetryConfig.exporterHeaders)
    var tracerProviderBuilder = TracerProviderBuilder()
      .with(resource: resource)
      .add(spanProcessor: SessionSpanProcessor())
    if screenConfig.stampsSpans {
      tracerProviderBuilder = tracerProviderBuilder.add(spanProcessor: ScreenSpanProcessor())
    }
    OpenTelemetry.registerTracerProvider(tracerProvider:
      tracerProviderBuilder
        .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
        .build()
    )

    let logExporter = OtlpHttpLogExporter(endpoint: logsEndpoint,
                                          envVarHeaders: TelemetryConfig.exporterHeaders)
    let logBatchProcessor = BatchLogRecordProcessor(logRecordExporter: logExporter)
    OpenTelemetry.registerLoggerProvider(loggerProvider:
      LoggerProviderBuilder()
        .with(resource: resource)
        .with(processors: [
          SessionLogRecordProcessor(nextProcessor: screenConfig.stampsLogs
            ? ScreenLogRecordProcessor(nextProcessor: logBatchProcessor)
            : logBatchProcessor),
          ScreenStackLogRecordProcessor()
        ])
        .build()
    )

    SessionEventInstrumentation.install()

    // Installed in didFinishLaunching, before the app first becomes active, so it sees the
    // activation that ends the cold start.
    if !IntegrationTestScenario.installsAppLaunchLate {
      MincoreLaunchInstrumentation.install()
    }

    // Installed after the providers are registered, because the first screen appears right
    // after this returns. Swizzling UIViewController reports the UIKit screens; the Settings
    // tab is SwiftUI and reports itself through .otelScreen in SettingsView.
    ScreenInstrumentationUIKit.install(config: TelemetryConfig.screenUIKitConfig,
                                       screenTracker: TelemetryConfig.screenTracker)

    // Installed after the session manager and logger provider are registered:
    // crashes from the previous run are reported on install, and each crash
    // records the session that was current when it happened.
    KSCrashInstrumentation.install(config: TelemetryConfig.crashConfig)

    // Skip the exporter's own OTLP requests, otherwise every export produces
    // a span that triggers another export.
    urlSessionInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration(
      shouldInstrument: { request in
        guard let url = request.url else { return true }
        return url != tracesEndpoint && url != logsEndpoint
      },
      semanticConvention: TelemetryConfig.httpSemanticConvention
    ))

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

// Screen settings edited from the Settings tab. Read once at startup by
// TelemetryConfig.screenTracker and TelemetryConfig.screenUIKitConfig.
enum ScreenConfigStore {
  private static let key = "HackerNewsDemo.screen.config"

  /// Which bundle's view controllers the UIKit front end reports.
  enum UIKitBundle: String, Codable, CaseIterable {
    case main
    case uikit

    var bundle: Bundle {
      switch self {
      case .main: .main
      case .uikit: Bundle(for: UIViewController.self)
      }
    }

    var label: String {
      switch self {
      case .main: "App"
      case .uikit: "UIKit"
      }
    }
  }

  /// An optional override: `inherit` keeps the tracker's own value.
  enum Override: String, Codable, CaseIterable {
    case inherit
    case on
    case off

    var value: Bool? {
      switch self {
      case .inherit: nil
      case .on: true
      case .off: false
      }
    }
  }

  struct Values: Codable, Equatable {
    var tracksNavigation = true
    var recordsTimeToFirstDraw = true
    var uikitBundle = UIKitBundle.main
    var uikitRecordsTimeToFirstDraw = Override.inherit
    var tracksHostingControllers = false
    var stampsSpans = true
    var stampsLogs = true

    init() {}

    // Decodes field by field so a value saved before a field existed keeps its default.
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let defaults = Values()
      tracksNavigation = try container.decodeIfPresent(Bool.self, forKey: .tracksNavigation) ?? defaults.tracksNavigation
      recordsTimeToFirstDraw = try container.decodeIfPresent(Bool.self, forKey: .recordsTimeToFirstDraw) ?? defaults.recordsTimeToFirstDraw
      uikitBundle = try container.decodeIfPresent(UIKitBundle.self, forKey: .uikitBundle) ?? defaults.uikitBundle
      uikitRecordsTimeToFirstDraw = try container.decodeIfPresent(Override.self, forKey: .uikitRecordsTimeToFirstDraw) ?? defaults.uikitRecordsTimeToFirstDraw
      tracksHostingControllers = try container.decodeIfPresent(Bool.self, forKey: .tracksHostingControllers) ?? defaults.tracksHostingControllers
      stampsSpans = try container.decodeIfPresent(Bool.self, forKey: .stampsSpans) ?? defaults.stampsSpans
      stampsLogs = try container.decodeIfPresent(Bool.self, forKey: .stampsLogs) ?? defaults.stampsLogs
    }
  }

  static func load() -> Values {
    guard let data = UserDefaults.standard.data(forKey: key),
          let values = try? JSONDecoder().decode(Values.self, from: data) else {
      return Values()
    }
    return values
  }

  static func save(_ values: Values) {
    UserDefaults.standard.set(try? JSONEncoder().encode(values), forKey: key)
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
