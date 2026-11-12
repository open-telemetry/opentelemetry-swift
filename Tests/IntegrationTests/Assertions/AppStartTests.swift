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
// `app-start-mincore` is the launch whose whole span tree is checked. The launches the runner drives
// through the background — `app-start-resume`, `app-start-late-install`, `app-start-background`,
// `app-start-update` and `app-start-reinstall` — are checked for the spans their scenario is for.
// Prewarming can't be triggered in the simulator, focus loss needs a system alert dismissed, and an
// iPhone app can't destroy its only scene to have a new one connect when it resumes, so they're
// only covered by the unit tests.
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

  private func roots(_ name: String, in launch: Scenario.Launch) -> [ProtoSpan] {
    OTLPOutput.launch(launch).spans
      .filter { $0.scope.name == Self.scope && $0.span.name == name }
      .map(\.span)
      .sorted { $0.startTimeUnixNano < $1.startTimeUnixNano }
  }

  /// The launch type is this library's verdict rather than a property of the launch: it's measured
  /// from the sampled pages when those could be read, and inferred from the launch history
  /// otherwise. A simulator launch reads the Mac's page cache, so which of the two a launch gets
  /// isn't predictable from here and both rules are checked. `inferredType` is what the history
  /// says for this launch, from the causes in the module's README.
  private func assertClassification(_ span: ProtoSpan, inferredType: App.StartTypeValues,
                                    in launch: Scenario.Launch,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
    let determinedBy = try XCTUnwrap(span.attributes.string(App.startDeterminedBy.rawValue),
                                     "\(launch): no app.start.determined_by", file: file, line: line)
    let type = span.attributes.string(App.startType.rawValue)
    switch determinedBy {
    case App.StartDeterminedByValues.pageSampling.description:
      let residentAtEnd = try XCTUnwrap(span.attributes.int(App.startPagesTextResidentAtEnd.rawValue), "\(launch)", file: file, line: line)
      let pagedIn = try XCTUnwrap(span.attributes.int(App.startPagesTextPagedIn.rawValue), "\(launch)", file: file, line: line)
      let ratio = try XCTUnwrap(span.attributes.double(App.startPagesTextPageInRatio.rawValue), "\(launch)", file: file, line: line)
      XCTAssertGreaterThan(residentAtEnd, 0, "\(launch)", file: file, line: line)
      XCTAssertEqual(ratio, Double(pagedIn) / Double(residentAtEnd), accuracy: 1e-9, "\(launch)", file: file, line: line)
      XCTAssertEqual(type, (ratio >= 0.5 ? App.StartTypeValues.cold : .warm).description,
                     "\(launch): the type must follow the ratio and the default threshold", file: file, line: line)
    case App.StartDeterminedByValues.launchHistory.description:
      XCTAssertEqual(type, inferredType.description,
                     "\(launch): the launch history decides when the pages can't be sampled", file: file, line: line)
      XCTAssertNil(span.attributes.double(App.startPagesTextPageInRatio.rawValue),
                   "\(launch): a launch classified from history has no ratio", file: file, line: line)
    default:
      XCTFail("\(launch): unexpected app.start.determined_by \(determinedBy)", file: file, line: line)
    }
  }

  // MARK: mincore

  func testMincoreLaunchMatchesTheSchema() throws {
    let spans = OTLPOutput.launch(.appStartMincore).spans.filter { $0.scope.name == Self.scope }
    let root = try XCTUnwrap(spans.first { $0.span.name == "app.start" })
    XCTAssertEqual(spans.filter { $0.span.name == "app.start" }.count, 1)
    let span = root.span
    XCTAssertEqual(span.kind, .internal)
    XCTAssertTrue(span.parentSpanID.isEmpty)

    let residentAtEnd = try XCTUnwrap(span.attributes.int(App.startPagesTextResidentAtEnd.rawValue))
    let pagedIn = try XCTUnwrap(span.attributes.int(App.startPagesTextPagedIn.rawValue))
    let ratio = try XCTUnwrap(span.attributes.double(App.startPagesTextPageInRatio.rawValue))
    XCTAssertGreaterThan(residentAtEnd, 0)
    XCTAssertLessThanOrEqual(residentAtEnd, 256)
    XCTAssertLessThanOrEqual(pagedIn, residentAtEnd)
    let sampled = try XCTUnwrap(span.attributes.int(App.startPagesTextSampled.rawValue))
    XCTAssertGreaterThanOrEqual(sampled, residentAtEnd)
    XCTAssertLessThanOrEqual(sampled, 256)
    XCTAssertEqual(ratio, Double(pagedIn) / Double(residentAtEnd), accuracy: 1e-9)
    let type = ratio >= 0.5 ? App.StartTypeValues.cold : App.StartTypeValues.warm
    XCTAssertEqual(span.attributes.string(App.startType.rawValue), type.description)
    XCTAssertEqual(span.attributes.string(App.startOutcome.rawValue), App.StartOutcomeValues.completed.description)
    XCTAssertEqual(span.attributes.string(App.startDeterminedBy.rawValue), App.StartDeterminedByValues.pageSampling.description)
    XCTAssertNotNil(span.attributes.int(App.startPageInsBeforeTextSample.rawValue))
    XCTAssertNotNil(span.attributes.int(App.startPageInsAfterTextSample.rawValue))

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


  // MARK: the launches the runner drives through the background

  // `app-start-resume`: the runner opens Settings once the launch's first frame is displayed, then
  // launches the app again, which brings the running process back to the foreground.
  func testResumeLaunchRecordsItsLaunchAndOneHotResume() throws {
    let launch = Scenario.Launch.appStartResume
    let starts = roots("app.start", in: launch)
    XCTAssertEqual(starts.count, 1, "the process launched once")
    let start = try XCTUnwrap(starts.first)
    XCTAssertEqual(start.attributes.string(App.startOutcome.rawValue), App.StartOutcomeValues.completed.description)
    // Launched after `main`, with the same build from the same install directory and no reboot in
    // between, so the launch history says its code was already in memory.
    try assertClassification(start, inferredType: .warm, in: launch)
    assertDiffer(start.startTimeUnixNano, from: try processStart(launch), byAtMost: Self.clockTolerance,
                 "\(launch): a launch that wasn't prewarmed starts at process start")

    let resumes = roots("app.resume", in: launch)
    XCTAssertEqual(resumes.count, 1, "the app returned to the foreground once")
    let resume = try XCTUnwrap(resumes.first)
    XCTAssertEqual(resume.kind, .internal)
    XCTAssertTrue(resume.parentSpanID.isEmpty)
    XCTAssertEqual(resume.attributes.string(App.resumeType.rawValue), App.ResumeTypeValues.hot.description,
                   "the scene stayed connected while the app was in the background")
    XCTAssertEqual(resume.attributes.string(App.resumeOutcome.rawValue), App.ResumeOutcomeValues.completed.description)
    // No scene connects when the app comes back, so the resume starts at `willEnterForeground`.
    assertDiffer(resume.startTimeUnixNano, from: try XCTUnwrap(markers(Scenario.foregroundSpanName, in: launch).last),
                 byAtMost: Self.clockTolerance, "\(launch): a resume starts when the app enters the foreground")
    assertEndsAtFirstFrame(resume, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).last), in: launch)
    XCTAssertNotNil(resume.attributes.double(App.resumeBackgroundDuration.rawValue),
                    "the app was in the background before this resume")
    // The page baseline is taken when the app enters the background, which it did here.
    let sampled = try XCTUnwrap(resume.attributes.int(App.resumePagesTextSampled.rawValue))
    let residentAtEnd = try XCTUnwrap(resume.attributes.int(App.resumePagesTextResidentAtEnd.rawValue))
    let pagedIn = try XCTUnwrap(resume.attributes.int(App.resumePagesTextPagedIn.rawValue))
    XCTAssertLessThanOrEqual(sampled, 256)
    XCTAssertLessThanOrEqual(residentAtEnd, sampled)
    XCTAssertLessThanOrEqual(pagedIn, residentAtEnd)
    if residentAtEnd > 0 {
      XCTAssertEqual(try XCTUnwrap(resume.attributes.double(App.resumePagesTextPageInRatio.rawValue)),
                     Double(pagedIn) / Double(residentAtEnd), accuracy: 1e-9)
    } else {
      XCTAssertNil(resume.attributes.double(App.resumePagesTextPageInRatio.rawValue),
                   "with nothing resident there's nothing to take a share of")
    }
  }

  // `app-start-late-install`: the instrumentation is installed after the app first became active,
  // so that launch can't be measured. The second activation blocks the main thread while the runner
  // opens Settings, so the app is in the background before its first frame and that activation
  // can't be measured either. The third is a resume that completes.
  func testLateInstallRecordsNoLaunchAndOnlyOneCompletedResume() throws {
    let launch = Scenario.Launch.appStartLateInstall
    XCTAssertTrue(roots("app.start", in: launch).isEmpty,
                  "the app was already active when the instrumentation was installed, so there's no launch to measure")

    let resumes = roots("app.resume", in: launch)
    let completed = resumes.filter { $0.attributes.string(App.resumeOutcome.rawValue) == App.ResumeOutcomeValues.completed.description }
    XCTAssertEqual(completed.count, 1, "only the third activation reached a first frame")
    let resume = try XCTUnwrap(completed.first)
    XCTAssertEqual(resume.attributes.string(App.resumeType.rawValue), App.ResumeTypeValues.hot.description)
    assertDiffer(resume.startTimeUnixNano, from: try XCTUnwrap(markers(Scenario.foregroundSpanName, in: launch).last),
                 byAtMost: Self.clockTolerance, "\(launch): a resume starts when the app enters the foreground")
    assertEndsAtFirstFrame(resume, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).last), in: launch)
    // The interrupted activation is either not recorded or recorded as abandoned, never as a
    // resume that completed, and it must not end at the frame the next activation displayed.
    for interrupted in resumes where interrupted.spanID != resume.spanID {
      XCTAssertEqual(interrupted.attributes.string(App.resumeOutcome.rawValue), App.ResumeOutcomeValues.abandoned.description,
                     "the app left the foreground before this activation's first frame")
      XCTAssertLessThan(interrupted.endTimeUnixNano, resume.startTimeUnixNano)
    }
  }

  // `app-start-background`: the runner sends a silent push, so the system launches the app in the
  // background and connects its scene there, then brings it to the foreground.
  func testBackgroundLaunchRecordsNoLaunchAndABackgroundLaunchedResume() throws {
    let launch = Scenario.Launch.appStartBackground
    XCTAssertTrue(roots("app.start", in: launch).isEmpty,
                  "the process was started in the background, so it never launched into the foreground")

    let resumes = roots("app.resume", in: launch)
    XCTAssertEqual(resumes.count, 1)
    let resume = try XCTUnwrap(resumes.first)
    XCTAssertEqual(resume.attributes.string(App.resumeType.rawValue), App.ResumeTypeValues.backgroundLaunched.description,
                   "the system started the process in the background and it had never been active")
    XCTAssertEqual(resume.attributes.string(App.resumeOutcome.rawValue), App.ResumeOutcomeValues.completed.description)
    // The scene connected in the background seconds earlier, and the runner waits for the ready
    // marker before bringing the app forward, so the resume starts at `willEnterForeground`.
    assertDiffer(resume.startTimeUnixNano, from: try XCTUnwrap(markers(Scenario.foregroundSpanName, in: launch).last),
                 byAtMost: Self.clockTolerance, "\(launch): a resume starts when the app enters the foreground")
    assertEndsAtFirstFrame(resume, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).last), in: launch)
    // The app was never in the foreground to leave, so no page baseline was taken and it was never
    // in the background for a measured length of time.
    XCTAssertNil(resume.attributes.int(App.resumePagesTextPagedIn.rawValue))
    XCTAssertNil(resume.attributes.double(App.resumePagesTextPageInRatio.rawValue))
    XCTAssertNil(resume.attributes.double(App.resumeBackgroundDuration.rawValue))
  }

  // `app-start-update` reinstalls the app with its build number bumped, as an update does, and
  // `app-start-reinstall` installs the same build again, so only the install directory differs.
  // Both are causes the launch history calls `cold`.
  func testUpdateAndReinstallRecordOneLaunchTheHistoryWouldCallCold() throws {
    for launch in [Scenario.Launch.appStartUpdate, .appStartReinstall] {
      let starts = roots("app.start", in: launch)
      XCTAssertEqual(starts.count, 1, "\(launch): the process launched once")
      let start = try XCTUnwrap(starts.first, "\(launch)")
      XCTAssertTrue(roots("app.resume", in: launch).isEmpty, "\(launch): the runner never backgrounds it")
      XCTAssertTrue(start.parentSpanID.isEmpty, "\(launch)")
      XCTAssertEqual(start.attributes.string(App.startOutcome.rawValue), App.StartOutcomeValues.completed.description, "\(launch)")
      try assertClassification(start, inferredType: .cold, in: launch)
      assertDiffer(start.startTimeUnixNano, from: try processStart(launch), byAtMost: Self.clockTolerance,
                   "\(launch): a launch that wasn't prewarmed starts at process start")
      assertEndsAtFirstFrame(start, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).first), in: launch)
    }
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
