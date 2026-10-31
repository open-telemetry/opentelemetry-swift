/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Darwin
import InstrumentationSemanticConventions
import XCTest

// Checks the AppStart spans against their definition in the federated semantic conventions
// (Sources/Instrumentation/SemanticConventions/model/swift/spans.yaml). The app records its process
// start and lifecycle notifications as zero-length marker spans, read independently of
// the app launch libraries, so each span's timestamps are compared with them. Attribute keys and
// values come from the constants generated from that registry, so the spans are checked against
// the registry rather than against copies of its strings.
//
// Launches: `main` is the first after installation, so it's cold. The other session launches and
// `app-start-resume` run after it in the same boot with the same build, so they're warm, and
// `app-start-resume` then returns to the foreground for a resume. `app-start-late-install` installs the instrumentation after the app became active, and is moved
// to the background before one activation's first frame. `app-start-background` is launched in
// the background by a silent push and later brought to the foreground. `app-start-update` is the
// first launch after the runner installed a new build, and `app-start-reinstall` the first after it
// installed that build again, so both are cold. Prewarming can't be
// triggered in the simulator, focus loss needs a system alert dismissed, and an iPhone app can't
// destroy its only scene to have a new one connect when it resumes, so they're only covered by
// the unit tests.
final class AppStartTests: XCTestCase {
  private static let scope = "io.opentelemetry.lifecycle"
  private static let spanName = "AppStart"
  private typealias Start = FederatedSemanticConventions.Start
  private static let typeKey = Start.type.rawValue
  private static let activePrewarmedKey = Start.activePrewarmed.rawValue
  private static let registryKeys = Set(Start.allCases.map(\.rawValue))
  // Other components add their own attributes, such as `session.id` from the session span
  // processor, so only keys in the registry's namespace are checked against it.
  private static let registryNamespace = "start."
  private static let cold = Start.TypeValues.cold.description
  private static let warm = Start.TypeValues.warm.description
  private static let resume = Start.TypeValues.resume.description
  private static let types = [cold, warm, resume]
  private static let nanosecondsPerSecond: UInt64 = 1_000_000_000
  private static let maxLaunchDuration = 60 * nanosecondsPerSecond
  // How long after `didBecomeActive` the first frame may be displayed. Generous for slow CI
  // simulators, and shorter than the 2 seconds the app waits before it completes.
  private static let firstFrameTolerance = nanosecondsPerSecond * 3 / 2
  // Timestamps the app and the instrumentation read from the same clock or kernel value, but
  // convert separately.
  private static let clockTolerance: UInt64 = 1_000_000
  // How far apart the instrumentation's and the app's observers of the same notification run.
  private static let observerTolerance: UInt64 = 100_000_000

  // Every launch whose output is complete. `crash` dies right after its completion marker, so its
  // AppStart span may not be exported.
  private static let launches: [Scenario.Launch] = [
    .main, .maxLifetime, .restoreFirst, .restoreSecond, .noRestore, .crashReport, .logLimits,
    .appStartResume, .appStartLateInstall, .appStartBackground, .appStartUpdate, .appStartReinstall, .appStartMeasured,
  ]
  // Launches where every activation is recorded.
  private static let fullyRecordedLaunches = launches.filter { $0 != .appStartLateInstall }
  private static let warmLaunches: [Scenario.Launch] = [
    .maxLifetime, .restoreFirst, .restoreSecond, .noRestore, .crashReport, .logLimits,
  ]

  private func appStarts(_ launch: Scenario.Launch) -> [ExportedSpan] {
    OTLPOutput.launch(launch).spans
      .filter { $0.scope.name == Self.scope && $0.span.name == Self.spanName }
      .sorted { $0.span.startTimeUnixNano < $1.span.startTimeUnixNano }
  }

  private func markers(_ name: String, in launch: Scenario.Launch) -> [UInt64] {
    OTLPOutput.launch(launch).spans
      .filter { $0.scope.name == Scenario.scope && $0.span.name == name }
      .map(\.span.startTimeUnixNano)
      .sorted()
  }

  private func processStart(_ launch: Scenario.Launch) throws -> UInt64 {
    try XCTUnwrap(markers(Scenario.processStartSpanName, in: launch).first, "no process start marker in \(launch)")
  }

  private func appStart(_ launch: Scenario.Launch) throws -> ProtoSpan {
    let spans = appStarts(launch)
    XCTAssertEqual(spans.count, 1, "AppStart spans in \(launch)")
    return try XCTUnwrap(spans.first, "no AppStart span in \(launch)").span
  }

  private func assertIsResume(_ span: ProtoSpan, activation: UInt64, in launch: Scenario.Launch,
                              file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(span.attributes.string(Self.typeKey), Self.resume, "\(launch)", file: file, line: line)
    // None of the launches has a scene connect as the app returns to the foreground, so every
    // resume starts at `willEnterForeground`.
    let foreground = try XCTUnwrap(markers(Scenario.foregroundSpanName, in: launch).last { $0 < activation },
                                   "\(launch): no willEnterForeground before the activation", file: file, line: line)
    assertDiffer(span.startTimeUnixNano, from: foreground, byAtMost: Self.observerTolerance,
                 "\(launch): a resume starts when the app begins returning to the foreground", file: file, line: line)
    assertEndsAtFirstFrame(span, activation: activation, in: launch, file: file, line: line)
  }

  private func processStartTaskRole(_ launch: Scenario.Launch) -> Int64? {
    OTLPOutput.launch(launch).spans
      .first { $0.scope.name == Scenario.scope && $0.span.name == Scenario.processStartSpanName }?
      .span.attributes.int(Scenario.taskRoleAttributeKey)
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

  // MARK: Span definition

  func testEveryAppStartMatchesSpanDefinition() {
    for launch in Self.launches {
      for exported in appStarts(launch) {
        let span = exported.span
        XCTAssertEqual(span.kind, .internal, "\(launch)")
        XCTAssertTrue(span.parentSpanID.isEmpty, "\(launch): AppStart is a root span")

        let type = span.attributes.string(Self.typeKey)
        XCTAssertTrue(Self.types.contains(type ?? ""), "\(launch): start.type is required, got \(String(describing: type))")
        if type == Self.resume {
          XCTAssertNil(span.attributes[Self.activePrewarmedKey], "\(launch): start.active_prewarmed is only set on launches")
        } else {
          XCTAssertNotNil(span.attributes.bool(Self.activePrewarmedKey), "\(launch): start.active_prewarmed is required on \(type ?? "")")
        }
        let keys = Set(span.attributes.map(\.key).filter { $0.hasPrefix(Self.registryNamespace) })
        XCTAssertTrue(keys.isSubset(of: Self.registryKeys), "\(launch): attributes not in the registry: \(keys.subtracting(Self.registryKeys))")

        XCTAssertGreaterThanOrEqual(span.endTimeUnixNano, span.startTimeUnixNano, "\(launch)")
        if type != Self.resume {
          XCTAssertLessThanOrEqual(span.endTimeUnixNano - span.startTimeUnixNano, Self.maxLaunchDuration,
                                   "\(launch): launches longer than maxLaunchDuration must be dropped")
        }
      }
    }
  }

  func testOneAppStartPerActivation() {
    for launch in Self.fullyRecordedLaunches {
      XCTAssertEqual(appStarts(launch).count, markers(Scenario.activeSpanName, in: launch).count,
                     "\(launch): AppStart spans vs didBecomeActive notifications")
    }
  }

  // MARK: cold and warm

  func testFirstLaunchAfterInstallationIsCold() throws {
    let span = try appStart(.main)
    XCTAssertEqual(span.attributes.string(Self.typeKey), Self.cold)
    XCTAssertEqual(span.attributes.bool(Self.activePrewarmedKey), false)
    assertDiffer(span.startTimeUnixNano, from: try processStart(.main), byAtMost: Self.clockTolerance,
                 "cold starts at process start")
    assertEndsAtFirstFrame(span, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: .main).first), in: .main)
  }

  func testLaterLaunchesInSameBootAndBuildAreWarm() throws {
    for launch in Self.warmLaunches {
      let span = try appStart(launch)
      XCTAssertEqual(span.attributes.string(Self.typeKey), Self.warm, "\(launch)")
      XCTAssertEqual(span.attributes.bool(Self.activePrewarmedKey), false, "\(launch)")
      assertDiffer(span.startTimeUnixNano, from: try processStart(launch), byAtMost: Self.clockTolerance,
                   "\(launch): warm starts at process start")
      assertEndsAtFirstFrame(span, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).first), in: launch)
    }
  }

  // `app-start-reinstall` installs the same build as `app-start-update`, so only the install differs.
  func testFirstLaunchAfterUpdateOrReinstallIsCold() throws {
    for launch in [Scenario.Launch.appStartUpdate, .appStartReinstall] {
      let span = try appStart(launch)
      XCTAssertEqual(span.attributes.string(Self.typeKey), Self.cold, "\(launch)")
      XCTAssertEqual(span.attributes.bool(Self.activePrewarmedKey), false, "\(launch)")
      assertDiffer(span.startTimeUnixNano, from: try processStart(launch), byAtMost: Self.clockTolerance,
                   "cold starts at process start")
      assertEndsAtFirstFrame(span, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: launch).first),
                             in: launch)
    }
  }

  // MARK: measured

  func testMeasuredLaunchAgreesWithItsSampledPages() throws {
    let span = try appStart(.appStartMeasured)
    let residentAtEnd = try XCTUnwrap(span.attributes.int(Start.sampledPagesResidentAtEnd.rawValue))
    let pagedIn = try XCTUnwrap(span.attributes.int(Start.sampledPagesPagedIn.rawValue))
    let ratio = try XCTUnwrap(span.attributes.double(Start.sampledPageInRatio.rawValue))

    XCTAssertGreaterThan(residentAtEnd, 0)
    XCTAssertLessThanOrEqual(residentAtEnd, 256)
    XCTAssertLessThanOrEqual(pagedIn, residentAtEnd)
    XCTAssertEqual(ratio, Double(pagedIn) / Double(residentAtEnd), accuracy: 1e-9)
    XCTAssertEqual(span.attributes.string(Self.typeKey), ratio >= 0.5 ? Self.cold : Self.warm)
    assertDiffer(span.startTimeUnixNano, from: try processStart(.appStartMeasured), byAtMost: Self.clockTolerance,
                 "a measured launch starts at process start")
    assertEndsAtFirstFrame(span, activation: try XCTUnwrap(markers(Scenario.activeSpanName, in: .appStartMeasured).first),
                           in: .appStartMeasured)
  }

  func testInferredLaunchesHaveNoSampledPages() {
    for launch in Self.launches where launch != .appStartMeasured {
      for exported in appStarts(launch) {
        XCTAssertNil(exported.span.attributes[Start.sampledPageInRatio.rawValue], "\(launch)")
      }
    }
  }

  // MARK: resume

  func testReturnToForegroundIsResume() throws {
    let spans = appStarts(.appStartResume).map(\.span)
    XCTAssertEqual(spans.map { $0.attributes.string(Self.typeKey) }, [Self.warm, Self.resume])
    let activations = markers(Scenario.activeSpanName, in: .appStartResume)
    let foregrounds = markers(Scenario.foregroundSpanName, in: .appStartResume)
    guard spans.count == 2, activations.count == 2 else { return }

    let launch = spans[0]
    assertDiffer(launch.startTimeUnixNano, from: try processStart(.appStartResume), byAtMost: Self.clockTolerance,
                 "warm starts at process start")
    assertEndsAtFirstFrame(launch, activation: activations[0], in: .appStartResume)

    let resume = spans[1]
    let foreground = try XCTUnwrap(foregrounds.last, "no willEnterForeground marker")
    assertDiffer(resume.startTimeUnixNano, from: foreground, byAtMost: Self.observerTolerance,
                 "resume starts at willEnterForeground")
    XCTAssertGreaterThan(resume.startTimeUnixNano, launch.endTimeUnixNano)
    assertEndsAtFirstFrame(resume, activation: activations[1], in: .appStartResume)
  }

  // MARK: Late installation and interrupted activations

  func testInstallAfterAppBecameActiveSkipsLaunch() throws {
    let launch = Scenario.Launch.appStartLateInstall
    let activations = markers(Scenario.activeSpanName, in: launch)
    XCTAssertEqual(activations.count, 3, "activations")
    let spans = appStarts(launch).map(\.span)
    XCTAssertEqual(spans.map { $0.attributes.string(Self.typeKey) }, [Self.resume],
                   "the launch isn't recorded, the interrupted activation is dropped, and the last one is a resume")
    let first = try XCTUnwrap(activations.first)
    XCTAssertFalse(spans.contains { $0.startTimeUnixNano <= first }, "no span for the launch")
  }

  func testEnteringBackgroundBeforeFirstFrameDropsActivation() throws {
    let launch = Scenario.Launch.appStartLateInstall
    let activations = markers(Scenario.activeSpanName, in: launch)
    guard activations.count == 3 else { return XCTFail("expected 3 activations") }
    XCTAssertNotNil(markers(Scenario.backgroundSpanName, in: launch).first { $0 > activations[1] && $0 < activations[2] },
                    "the runner moved the app to the background during the second activation")
    let spans = appStarts(launch).map(\.span)
    XCTAssertFalse(spans.contains { $0.endTimeUnixNano > activations[1] && $0.endTimeUnixNano < activations[2] },
                   "the interrupted activation isn't recorded")
    let resume = try XCTUnwrap(spans.last)
    try assertIsResume(resume, activation: activations[2], in: launch)
  }

  // MARK: Background launch

  func testFirstForegroundAfterBackgroundLaunchIsResume() throws {
    let launch = Scenario.Launch.appStartBackground
    let processStart = try processStart(launch)
    let activations = markers(Scenario.activeSpanName, in: launch)
    XCTAssertEqual(activations.count, 1, "activations")
    let activation = try XCTUnwrap(activations.first)
    XCTAssertGreaterThan(activation, processStart + Self.nanosecondsPerSecond,
                         "the app was in the background for a while before the runner brought it to the foreground")

    let spans = appStarts(launch).map(\.span)
    XCTAssertEqual(spans.map { $0.attributes.string(Self.typeKey) }, [Self.resume],
                   "the process was alive, so its first activation is a resume, not a launch from process start")
    let span = try XCTUnwrap(spans.first)
    try assertIsResume(span, activation: activation, in: launch)
    XCTAssertNil(span.attributes[Self.activePrewarmedKey])

    // The system connected the scene while the app was in the background, which isn't when the
    // user started waiting.
    let sceneConnected = try XCTUnwrap(markers(Scenario.sceneConnectSpanName, in: launch).first)
    let foreground = try XCTUnwrap(markers(Scenario.foregroundSpanName, in: launch).first)
    XCTAssertGreaterThan(foreground, sceneConnected + Self.nanosecondsPerSecond,
                         "the scene connected in the background, well before the app entered the foreground")
    XCTAssertGreaterThan(span.startTimeUnixNano, sceneConnected + Self.nanosecondsPerSecond,
                         "the resume doesn't start when the scene connected in the background")
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
