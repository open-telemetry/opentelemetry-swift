/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Darwin
import InstrumentationSemanticConventions
import XCTest

// Checks the `app.start` spans recorded by MincoreLaunchInstrumentation against their definition in
// the federated semantic conventions
// (Sources/Instrumentation/SemanticConventions/model/swift/spans.yaml). The app records its process
// start and lifecycle notifications as zero-length marker spans, read independently of
// the app launch library, so each span's timestamps are compared with them. Attribute keys and
// values come from the constants generated from that registry, so the spans are checked against
// the registry rather than against copies of its strings.
//
// `app-start-mincore` is the launch checked. Prewarming can't be triggered in the simulator,
// focus loss needs a system alert dismissed, and an iPhone app can't destroy its only scene to have
// a new one connect when it resumes, so they're only covered by the unit tests.
final class AppStartTests: XCTestCase {
  private typealias App = FederatedSemanticConventions.App
  private static let scope = "io.opentelemetry.lifecycle"
  private static let nanosecondsPerSecond: UInt64 = 1_000_000_000
  // How long after `didBecomeActive` the first frame may be displayed. Generous for slow CI
  // simulators, and shorter than the 2 seconds the app waits before it completes.
  private static let firstFrameTolerance = nanosecondsPerSecond * 3 / 2
  // Timestamps the app and the instrumentation read from the same clock or kernel value, but
  // convert separately.
  private static let clockTolerance: UInt64 = 1_000_000

  // Every launch whose output is complete. `crash` dies right after its completion marker.
  private static let launches: [Scenario.Launch] = [
    .main, .maxLifetime, .restoreFirst, .restoreSecond, .noRestore, .crashReport, .logLimits,
    .appStartResume, .appStartLateInstall, .appStartBackground, .appStartUpdate, .appStartReinstall,
  ]

  private func markers(_ name: String, in launch: Scenario.Launch) -> [UInt64] {
    OTLPOutput.launch(launch).spans
      .filter { $0.scope.name == Scenario.scope && $0.span.name == name }
      .map(\.span.startTimeUnixNano)
      .sorted()
  }

  private func processStart(_ launch: Scenario.Launch) throws -> UInt64 {
    try XCTUnwrap(markers(Scenario.processStartSpanName, in: launch).first, "no process start marker in \(launch)")
  }

  private func assertEndsAtFirstFrame(_ span: ProtoSpan, activation: UInt64, in launch: Scenario.Launch,
                                      file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(span.endTimeUnixNano, activation,
                                "\(launch): must not end before didBecomeActive", file: file, line: line)
    XCTAssertLessThanOrEqual(span.endTimeUnixNano, activation + Self.firstFrameTolerance,
                             "\(launch): must end at the first frame after didBecomeActive", file: file, line: line)
  }

  private func assertDiffer(_ actual: UInt64, from expected: UInt64, byAtMost tolerance: UInt64, _ message: String,
                            file: StaticString = #filePath, line: UInt = #line) {
    let difference = actual > expected ? actual - expected : expected - actual
    XCTAssertLessThanOrEqual(difference, tolerance, message, file: file, line: line)
  }

  // MARK: mincore

  func testMincoreLaunchMatchesTheSchema() throws {
    let spans = OTLPOutput.launch(.appStartMincore).spans.filter { $0.scope.name == Self.scope }
    let root = try XCTUnwrap(spans.first { $0.span.name == "app.start" })
    XCTAssertEqual(spans.filter { $0.span.name == "app.start" }.count, 1)
    let span = root.span
    XCTAssertEqual(span.kind, .internal)
    XCTAssertTrue(span.parentSpanID.isEmpty)

    let residentAtEnd = try XCTUnwrap(span.attributes.int(App.startSampledPagesResidentAtEnd.rawValue))
    let pagedIn = try XCTUnwrap(span.attributes.int(App.startSampledPagesPagedIn.rawValue))
    let ratio = try XCTUnwrap(span.attributes.double(App.startSampledPageInRatio.rawValue))
    XCTAssertGreaterThan(residentAtEnd, 0)
    XCTAssertLessThanOrEqual(residentAtEnd, 256)
    XCTAssertLessThanOrEqual(pagedIn, residentAtEnd)
    let sampled = try XCTUnwrap(span.attributes.int(App.startSampledPagesTotal.rawValue))
    XCTAssertGreaterThanOrEqual(sampled, residentAtEnd)
    XCTAssertLessThanOrEqual(sampled, 256)
    XCTAssertEqual(ratio, Double(pagedIn) / Double(residentAtEnd), accuracy: 1e-9)
    let type = ratio >= 0.5 ? App.StartTypeValues.cold : App.StartTypeValues.warm
    XCTAssertEqual(span.attributes.string(App.startType.rawValue), type.description)
    XCTAssertEqual(span.attributes.string(App.startOutcome.rawValue), App.StartOutcomeValues.completed.description)
    XCTAssertEqual(span.attributes.string(App.startDeterminedBy.rawValue), App.StartDeterminedByValues.pageSampling.description)
    XCTAssertNotNil(span.attributes.int(App.startPageInsPreInitializer.rawValue))
    XCTAssertNotNil(span.attributes.int(App.startPageInsPostInitializer.rawValue))

    assertDiffer(span.startTimeUnixNano, from: try processStart(.appStartMincore), byAtMost: Self.clockTolerance,
                 "a launch that wasn't prewarmed starts at process start")
    assertEndsAtFirstFrame(span, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: .appStartMincore).first),
                           in: .appStartMincore)

    // The three top-level phases cover the span with no gaps.
    let phases = try ["app.start.pre_init", "app.start.app_init", "app.start.render"].map { name in
      try XCTUnwrap(spans.first { $0.span.name == name }, name).span
    }
    XCTAssertEqual(phases.first?.startTimeUnixNano, span.startTimeUnixNano)
    XCTAssertEqual(phases.last?.endTimeUnixNano, span.endTimeUnixNano)
    for (phase, next) in zip(phases, phases.dropFirst()) {
      XCTAssertEqual(phase.endTimeUnixNano, next.startTimeUnixNano)
    }
    for phase in phases {
      XCTAssertEqual(phase.traceID, span.traceID)
      XCTAssertEqual(phase.parentSpanID, span.spanID)
    }
    let sceneSetup = try XCTUnwrap(spans.first { $0.span.name == "app.start.scene_setup" }).span
    XCTAssertEqual(sceneSetup.parentSpanID, phases[2].spanID)
    XCTAssertGreaterThanOrEqual(sceneSetup.startTimeUnixNano, phases[2].startTimeUnixNano)
    XCTAssertEqual(sceneSetup.endTimeUnixNano, span.endTimeUnixNano)
  }


  private func processStartTaskRole(_ launch: Scenario.Launch) -> Int64? {
    OTLPOutput.launch(launch).spans
      .first { $0.scope.name == Scenario.scope && $0.span.name == Scenario.processStartSpanName }?
      .span.attributes.int(Scenario.taskRoleAttributeKey)
  }

  // The instrumentation detects a background launch from the role the system gave the process.
  // It reads the role before `main()` and the app in `didFinishLaunching`, so this checks the
  // premise; that the earlier read works shows in the launches' `start.type`.

  func testTaskRoleDistinguishesBackgroundLaunches() throws {
    let backgroundRoles = [TASK_BACKGROUND_APPLICATION, TASK_DARWINBG_APPLICATION, TASK_NONUI_APPLICATION]
      .map { Int64($0.rawValue) }
    let role = try XCTUnwrap(processStartTaskRole(.appStartBackground), "no role on the background launch")
    XCTAssertTrue(backgroundRoles.contains(role), "background launch role: \(role)")
    for launch in Self.launches where launch != .appStartBackground {
      let role = try XCTUnwrap(processStartTaskRole(launch), "no role on \(launch)")
      XCTAssertFalse(backgroundRoles.contains(role), "\(launch) role: \(role)")
    }
  }
}
