/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import XCTest

// Checks the AppStart spans against their definition in the federated semantic conventions
// (Sources/Instrumentation/SemanticConventions/model/swift/spans.yaml). The app records its process
// start and lifecycle notifications as zero-length marker spans, read independently of
// AppLaunchInstrumentation, so each span's timestamps are compared with them. Attribute keys and
// values come from the constants generated from that registry, so the spans are checked against
// the registry rather than against copies of its strings.
//
// Launches: `main` is the first after installation, so it's cold. The other session launches and
// `app-start-resume` run after it in the same boot with the same build, so they're warm, and
// `app-start-resume` then returns to the foreground for a resume. `app-start-update` is the first
// launch after the runner installed a new build, so it's cold. Prewarming can't be triggered in
// the simulator, so it's only covered by the unit tests.
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
    .appStartResume, .appStartUpdate,
  ]
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
    for launch in Self.launches {
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

  func testFirstLaunchAfterUpdateIsCold() throws {
    let span = try appStart(.appStartUpdate)
    XCTAssertEqual(span.attributes.string(Self.typeKey), Self.cold)
    XCTAssertEqual(span.attributes.bool(Self.activePrewarmedKey), false)
    assertDiffer(span.startTimeUnixNano, from: try processStart(.appStartUpdate), byAtMost: Self.clockTolerance,
                 "cold starts at process start")
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
}
