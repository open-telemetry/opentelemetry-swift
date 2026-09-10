/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

// Driven by Scripts/run-integration-tests.sh. When the app is launched with
// `--integrationTestMode` it produces a fixed set of telemetry against the local
// mock collector so Tests/IntegrationTests can assert on what was exported.
// Keep these names in sync with the assertions.
enum IntegrationTestScenario {
  static let launchArgument = "--integrationTestMode"
  static let scope = "HackerNewsDemo.IntegrationTest"

  static let rootSpanName = "integration.test.root"
  static let childSpanName = "integration.test.child"
  static let completionSpanName = "integration.test.complete"
  static let logBody = "integration test log"
  static let logEventName = "integration.test.event"
  static let attributeKey = "integration.test.attribute"
  static let attributeValue = "hello"
  static let statusCodes = [200, 404, 500]
  static let secondSessionSpanName = "integration.test.second-session"
  // Short enough that the scenario can let the first session expire and
  // observe session.end / session.start with session.previous_id.
  static let sessionTimeout: TimeInterval = 2

  static var isEnabled: Bool {
    ProcessInfo.processInfo.arguments.contains(launchArgument)
  }

  static func run() {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: scope)
    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scope)

    let root = tracer.spanBuilder(spanName: rootSpanName)
      .setSpanKind(spanKind: .client)
      .startSpan()
    root.setAttribute(key: attributeKey, value: attributeValue)

    let child = tracer.spanBuilder(spanName: childSpanName)
      .setParent(root)
      .startSpan()
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
      let url = TelemetryConfig.collectorBaseURL.appendingPathComponent("status/\(code)")
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
      tracer.spanBuilder(spanName: secondSessionSpanName).startSpan().end()

      tracer.spanBuilder(spanName: completionSpanName).startSpan().end()
      (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.forceFlush()
    }
  }
}
