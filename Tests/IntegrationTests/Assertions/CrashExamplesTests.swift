/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest

// Checks the crash examples collected by `Scripts/run-integration-tests.sh --crash-examples`:
// one crash per demo `CrashType` in `out/crash-examples/<type>/`, with KSCrash's raw report in
// `kscrash/` and the next launch's export in `report/`. Skipped in a normal run. Prints a
// Markdown table of what each crash was reported as, for the Crash README.
final class CrashExamplesTests: XCTestCase {
  private static let examplesPath = "crash-examples"
  private static let crashScope = "io.opentelemetry.kscrash"
  private static let crashEventName = "device.crash"

  /// Keep in sync with CrashType in Examples/HackerNewsDemo/HackerNewsDemo/CrashType.swift.
  private static let swiftTraps = ["fatal-error", "force-unwrap", "index-out-of-bounds", "divide-by-zero"]
  private static let crashTypes = swiftTraps + ["stack-overflow", "ns-exception", "bad-access"]

  override func setUpWithError() throws {
    let examples = OTLPOutput.baseDirectory.appendingPathComponent(Self.examplesPath)
    guard FileManager.default.fileExists(atPath: examples.path) else {
      throw XCTSkip("no crash examples; run Scripts/run-integration-tests.sh --crash-examples")
    }
  }

  private struct Example {
    let crashType: String
    let type: String
    let message: String
    let sessionId: String?
    let crashedSessionId: String?
  }

  private func example(_ crashType: String) throws -> Example {
    let crashed = OTLPOutput.subdirectory("\(Self.examplesPath)/\(crashType)")
    let reported = OTLPOutput.subdirectory("\(Self.examplesPath)/\(crashType)/report")

    // The previous example's report launch was terminated by the runner, so a termination report
    // can be in any launch; only the crash under test is of interest here.
    let crashes = reported.logs.filter {
      $0.scope.name == Self.crashScope && $0.record.eventName == Self.crashEventName &&
        $0.record.attributes.string("exception.type") != "termination"
    }
    XCTAssertEqual(crashes.count, 1, "\(crashType): expected exactly one crash on the launch after it")
    let crash = try XCTUnwrap(crashes.first, "\(crashType): no device.crash reported")

    let probe = crashed.spans.first { $0.span.name == Scenario.probeSpanName }
    return Example(crashType: crashType,
                   type: try XCTUnwrap(crash.record.attributes.string("exception.type")),
                   message: try XCTUnwrap(crash.record.attributes.string("exception.message")),
                   sessionId: crash.record.attributes.string("session.id"),
                   crashedSessionId: probe?.span.attributes.string("session.id"))
  }

  func testEveryCrashTypeIsReportedWithItsKindAndDescription() throws {
    var rows: [String] = []
    for crashType in Self.crashTypes {
      let example = try example(crashType)
      rows.append("| `\(crashType)` | `\(example.type)` | `\(example.message)` |")

      XCTAssertNotEqual(example.type, "crash", "\(crashType): the structured report was not decoded")
      XCTAssertFalse(example.message.isEmpty, "\(crashType): empty exception.message")
      XCTAssertNotNil(example.crashedSessionId, "\(crashType): no probe span from the crashing launch")
      XCTAssertEqual(example.sessionId, example.crashedSessionId, "\(crashType): not attributed to the session it crashed in")

      let raw = OTLPOutput.baseDirectory.appendingPathComponent("\(Self.examplesPath)/\(crashType)/kscrash")
      let rawReports = (try? FileManager.default.contentsOfDirectory(atPath: raw.path)) ?? []
      XCTAssertFalse(rawReports.filter { $0.hasSuffix(".json") }.isEmpty, "\(crashType): KSCrash's raw report was not saved")
    }
    print("| Crash | `exception.type` | `exception.message` |\n|---|---|---|\n" + rows.joined(separator: "\n"))
  }

  func testSwiftTrapsAreDescribedByTheRuntimeMessage() throws {
    // The demo is built for Debug, where the Swift runtime records why it trapped.
    for crashType in Self.swiftTraps {
      let example = try example(crashType)
      XCTAssertEqual(example.type, "EXC_BREAKPOINT (SIGTRAP)", crashType)
      XCTAssertTrue(example.message.contains("Fatal error"), "\(crashType): \(example.message)")
    }
  }

  func testUncaughtNSExceptionIsDescribedByItsNameAndReason() throws {
    let example = try example("ns-exception")
    XCTAssertEqual(example.type, "NSRangeException")
    XCTAssertTrue(example.message.hasPrefix("NSRangeException: "), example.message)
  }

  func testMemoryErrorsAreBadAccess() throws {
    for crashType in ["bad-access", "stack-overflow"] {
      let example = try example(crashType)
      XCTAssertTrue(example.type.hasPrefix("EXC_BAD_ACCESS"), "\(crashType): \(example.type)")
    }
  }
}
