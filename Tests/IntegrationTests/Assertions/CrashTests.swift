/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest

// The crash launch records its session in a probe span and then crashes. The
// crash-report launch runs in a new session and reports the stored crash, which
// must carry the session context from when the crash happened rather than the
// session that is current when it is reported.
final class CrashTests: XCTestCase {
  private static let crashScope = "io.opentelemetry.kscrash"
  private static let crashEventName = "device.crash"
  private static let sessionIdKey = "session.id"
  private static let previousSessionIdKey = "session.previous_id"
  private static let exceptionTypeKey = "exception.type"
  private static let exceptionMessageKey = "exception.message"
  private static let exceptionStacktraceKey = "exception.stacktrace"

  private func crashLogs(_ launch: Scenario.Launch) -> [ExportedLog] {
    OTLPOutput.launch(launch).logs.filter {
      $0.scope.name == Self.crashScope && $0.record.eventName == Self.crashEventName
    }
  }

  private func probe(_ launch: Scenario.Launch) throws -> ExportedSpan {
    try XCTUnwrap(OTLPOutput.launch(launch).spans.first {
      $0.span.name == Scenario.probeSpanName && $0.span.attributes.string(Scenario.launchAttributeKey) == launch.rawValue
    }, "no probe span from the \(launch.rawValue) launch")
  }

  private func reportedCrash() throws -> ExportedLog {
    let logs = crashLogs(.crashReport)
    XCTAssertEqual(logs.count, 1, "expected exactly one crash reported on the launch after the crash")
    return try XCTUnwrap(logs.first)
  }

  func testCrashIsReportedOnTheNextLaunch() throws {
    XCTAssertTrue(crashLogs(.crash).isEmpty, "the crashing launch cannot report its own crash")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.exceptionTypeKey), "crash")
    XCTAssertFalse(crash.record.attributes.string(Self.exceptionMessageKey)?.isEmpty ?? true, "missing \(Self.exceptionMessageKey)")
    XCTAssertFalse(crash.record.attributes.string(Self.exceptionStacktraceKey)?.isEmpty ?? true, "missing \(Self.exceptionStacktraceKey)")
  }

  func testCrashKeepsTheCrashedSessionId() throws {
    let crashedSession = try XCTUnwrap(probe(.crash).span.attributes.string(Self.sessionIdKey))
    let reportingSession = try XCTUnwrap(probe(.crashReport).span.attributes.string(Self.sessionIdKey))
    XCTAssertNotEqual(crashedSession, reportingSession, "the crash must be reported from a different session to prove its context was kept")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.sessionIdKey), crashedSession,
                   "the crash must carry the session it happened in, not the session that reported it")
  }

  func testCrashKeepsTheCrashedSessionPreviousId() throws {
    let crashedPreviousSession = try XCTUnwrap(probe(.crash).span.attributes.string(Self.previousSessionIdKey),
                                               "the crash launch starts a fresh session linked to the previous launch's")

    let crash = try reportedCrash()
    XCTAssertEqual(crash.record.attributes.string(Self.previousSessionIdKey), crashedPreviousSession)
  }

  func testCrashIsTimestampedWhenItHappened() throws {
    let crashedAfter = try probe(.crash).span.startTimeUnixNano
    let reportedAfter = try probe(.crashReport).span.startTimeUnixNano

    let crash = try reportedCrash()
    XCTAssertGreaterThan(crash.record.timeUnixNano, crashedAfter, "the crash happened after the crash launch's probe span")
    XCTAssertLessThan(crash.record.timeUnixNano, reportedAfter, "the crash must keep its own time, not the time it was reported")
  }

  // MARK: - Report content (default KSCrashInstrumentationConfig)

  /// Mirrors `KSCrashInstrumentationConfig.maxStackTraceBytes`'s default; the demo app installs with defaults.
  private static let defaultMaxStackTraceBytes = 25 * 1024

  private func reportLines() throws -> [String] {
    let report = try XCTUnwrap(reportedCrash().record.attributes.string(Self.exceptionStacktraceKey))
    return report.components(separatedBy: "\n")
  }

  private func headerValue(_ field: String, in lines: [String]) -> String? {
    lines.first { $0.hasPrefix("\(field):") }?
      .dropFirst(field.count + 1)
      .trimmingCharacters(in: .whitespaces)
  }

  /// The frames under the "Thread N Crashed:" header, and N.
  private func crashedThread(in lines: [String]) throws -> (number: String, frames: [String]) {
    let headerIndex = try XCTUnwrap(lines.firstIndex { $0.range(of: #"^Thread \d+ Crashed:$"#, options: .regularExpression) != nil },
                                    "no crashed thread section")
    let number = lines[headerIndex].replacingOccurrences(of: #"^Thread (\d+) Crashed:$"#, with: "$1", options: .regularExpression)
    let frames = lines[(headerIndex + 1)...].prefix { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    return (number, Array(frames))
  }

  func testCrashReportIsInAppleFormat() throws {
    let lines = try reportLines()
    XCTAssertTrue(lines.first?.hasPrefix("Incident Identifier:") ?? false, "an Apple crash report starts with its incident identifier")
    for field in ["Process", "Identifier", "OS Version", "Exception Type", "Triggered by Thread"] {
      XCTAssertNotNil(headerValue(field, in: lines), "missing the \(field) header")
    }
    XCTAssertEqual(headerValue("Identifier", in: lines), "io.opentelemetry.HackerNewsDemo")
    XCTAssertEqual(headerValue("Exception Type", in: lines), "EXC_BREAKPOINT (SIGTRAP)", "the scenario crashes with fatalError")

    let crashed = try crashedThread(in: lines)
    XCTAssertEqual(headerValue("Triggered by Thread", in: lines), crashed.number)
    XCTAssertFalse(crashed.frames.isEmpty, "the crashed thread has no frames")
  }

  func testCrashReportIsUnsymbolicatedByDefault() throws {
    // useOnDeviceSymbolication defaults to false, so frames are left as `<address> <load address> + <offset>`
    // for the backend to symbolicate.
    let frames = try crashedThread(in: reportLines()).frames
    let unsymbolicated = #"^\d+\s+\S+\s+0x[0-9a-f]+ 0x[0-9a-f]+ \+ \d+$"#
    for frame in frames {
      XCTAssertNotNil(frame.range(of: unsymbolicated, options: .regularExpression), "symbolicated or malformed frame: \(frame)")
    }
  }

  func testCrashReportFitsTheDefaultStackTraceLimit() throws {
    let report = try XCTUnwrap(reportedCrash().record.attributes.string(Self.exceptionStacktraceKey))
    XCTAssertLessThanOrEqual(report.utf8.count, Self.defaultMaxStackTraceBytes, "exception.stacktrace exceeds maxStackTraceBytes")
    // Cut at the end, so the identifying header and the crashed thread are always kept.
    XCTAssertTrue(report.hasPrefix("Incident Identifier:"))
  }

  func testCrashMessageDescribesTheCrashedFrame() throws {
    let lines = try reportLines()
    let crashed = try crashedThread(in: lines)
    // Frame format: "0   libswiftCore.dylib   0x0000000198272210 0x198171000 + 1053200"
    let topFrame = try XCTUnwrap(crashed.frames.first).split(whereSeparator: \.isWhitespace).map(String.init)
    XCTAssertGreaterThanOrEqual(topFrame.count, 4)
    let module = topFrame[1]
    let offset = try XCTUnwrap(topFrame.last)
    let exceptionType = try XCTUnwrap(headerValue("Exception Type", in: lines))

    let message = try reportedCrash().record.attributes.string(Self.exceptionMessageKey)
    XCTAssertEqual(message, "\(exceptionType) detected on thread \(crashed.number) at \(module) + \(offset)",
                   "exception.message must name the exception, the crashed thread and its top frame without the per-crash address")
  }
}
