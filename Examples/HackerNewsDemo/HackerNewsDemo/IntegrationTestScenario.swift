/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import Sessions

// Driven by Scripts/run-integration-tests.sh. When the app is launched with
// `--integrationTestMode` it produces a fixed set of telemetry against the local
// mock collector so Tests/IntegrationTests can assert on what was exported.
//
// The runner launches the app several times, each with `--integrationLaunch
// <tag>` and a session config passed as launch arguments, because SessionConfig
// is only read when the SessionManager is created. Keep the names in sync with
// the assertions.
enum IntegrationTestScenario {
  static let launchArgument = "--integrationTestMode"
  static let launchTagArgument = "--integrationLaunch"
  static let sessionTimeoutArgument = "--sessionTimeout"
  static let maxLifetimeArgument = "--maxLifetime"
  static let restorePersistedSessionArgument = "--restorePersistedSession"

  static let scope = "HackerNewsDemo.IntegrationTest"

  static let rootSpanName = "integration.test.root"
  static let childSpanName = "integration.test.child"
  static let completionSpanName = "integration.test.complete"
  static let logBody = "integration test log"
  static let logEventName = "integration.test.event"
  static let attributeKey = "integration.test.attribute"
  static let attributeValue = "hello"
  static let launchAttributeKey = "integration.test.launch"
  static let statusCodes = [200, 404, 500]
  static let secondSessionSpanName = "integration.test.second-session"
  static let heartbeatSpanName = "integration.test.heartbeat"
  static let probeSpanName = "integration.test.probe"

  enum Launch: String {
    // Fresh install. Exercises spans, logs, network and session expiry.
    case main
    // Continuous activity with a short max lifetime: the session must roll
    // over even though it never goes idle.
    case maxLifetime = "max-lifetime"
    // Two launches with restorePersistedSession = true: the second must keep
    // the first one's session id.
    case restoreFirst = "restore-first"
    case restoreSecond = "restore-second"
    // restorePersistedSession = false: a new session starts and the persisted
    // one becomes its previous session.
    case noRestore = "no-restore"
  }

  // Default session timeout for the main launch: short enough that the
  // scenario can let the first session expire and observe session.end /
  // session.start with session.previous_id.
  static let sessionTimeout: TimeInterval = 2

  private static let arguments = ProcessInfo.processInfo.arguments

  // Where the /status/<code> requests go. The runner's status server, passed
  // as SIMCTL_CHILD_INTEGRATION_STATUS_BASE_URL; falls back to the collector.
  static var statusBaseURL: URL {
    if let value = ProcessInfo.processInfo.environment["INTEGRATION_STATUS_BASE_URL"],
       let url = URL(string: value) {
      return url
    }
    return TelemetryConfig.collectorBaseURL
  }

  static var isEnabled: Bool {
    arguments.contains(launchArgument)
  }

  static var launch: Launch {
    value(after: launchTagArgument).flatMap(Launch.init(rawValue:)) ?? .main
  }

  static var sessionConfig: SessionConfig {
    let builder = SessionConfig.builder()
      .with(sessionTimeout: value(after: sessionTimeoutArgument).flatMap(TimeInterval.init) ?? sessionTimeout)
      .with(maxLifetime: value(after: maxLifetimeArgument).flatMap(TimeInterval.init))
    if let restore = value(after: restorePersistedSessionArgument).map({ $0 == "true" }) {
      builder.with(restorePersistedSession: restore)
    }
    return builder.build()
  }

  private static func value(after argument: String) -> String? {
    guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.endIndex else { return nil }
    return arguments[index + 1]
  }

  static func run() {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: scope)
    switch launch {
    case .main:
      runMain(tracer: tracer)
    case .maxLifetime:
      DispatchQueue.global().async {
        // Emit spans faster than any timeout so only maxLifetime can end the session.
        for _ in 0 ..< 12 {
          span(tracer, heartbeatSpanName).end()
          Thread.sleep(forTimeInterval: 0.5)
        }
        complete(tracer: tracer)
      }
    case .restoreFirst, .restoreSecond, .noRestore:
      DispatchQueue.global().async {
        span(tracer, probeSpanName).end()
        complete(tracer: tracer)
      }
    }
  }

  private static func runMain(tracer: Tracer) {
    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scope)

    let root = tracer.spanBuilder(spanName: rootSpanName)
      .setSpanKind(spanKind: .client)
      .startSpan()
    root.setAttribute(key: attributeKey, value: attributeValue)
    root.setAttribute(key: launchAttributeKey, value: launch.rawValue)

    let child = span(tracer, childSpanName, parent: root)
    child.addEvent(name: "child.event")
    child.end()
    root.end()

    logger.logRecordBuilder()
      .setEventName(logEventName)
      .setBody(.string(logBody))
      .setSeverity(.info)
      .setAttributes([attributeKey: .string(attributeValue)])
      .emit()

    let group = DispatchGroup()
    for code in statusCodes {
      group.enter()
      let url = statusBaseURL.appendingPathComponent("status/\(code)")
      URLSession.shared.dataTask(with: url) { _, _, _ in
        group.leave()
      }.resume()
    }

    group.notify(queue: .global()) {
      // The URLSession spans end asynchronously after the completion handler
      // runs, so give them a moment before the completion marker is emitted.
      Thread.sleep(forTimeInterval: 1)

      // Let the first session expire, then start a span in a fresh one.
      Thread.sleep(forTimeInterval: sessionTimeout + 1)
      span(tracer, secondSessionSpanName).end()

      complete(tracer: tracer)
    }
  }

  private static func complete(tracer: Tracer) {
    span(tracer, completionSpanName).end()
    (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.forceFlush()
  }

  private static func span(_ tracer: Tracer, _ name: String, parent: Span? = nil) -> Span {
    let builder = tracer.spanBuilder(spanName: name)
    if let parent {
      builder.setParent(parent)
    }
    let span = builder.startSpan()
    span.setAttribute(key: launchAttributeKey, value: launch.rawValue)
    return span
  }
}
