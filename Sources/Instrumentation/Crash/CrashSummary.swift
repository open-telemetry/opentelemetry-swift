/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import KSCrashReportModel

/// The `exception.type` and `exception.message` of a crash, read from KSCrash's structured report
/// rather than parsed back out of the Apple-format text.
struct CrashSummary: Equatable {
  /// The kind of crash: the NSException or C++ exception name, the Mach exception with its signal
  /// (`EXC_BAD_ACCESS (SIGSEGV)`, matching the Apple report's `Exception Type`), the signal, or
  /// KSCrash's error type (`termination`, `hang`, ...).
  let type: String

  /// The most descriptive text KSCrash recorded, in order of preference: the exception's reason,
  /// the Swift runtime's fatal error message, KSCrash's diagnosis, KSCrash's reason, and finally
  /// the type and the first frame in the app's own code (or the crashed frame) as module + offset.
  let message: String

  typealias Report = KSCrashReportModel.CrashReport<NoUserData>

  /// Decodes a raw KSCrash JSON report; `nil` when it cannot be decoded, e.g. a report that was
  /// only partly written.
  init?(reportJSON: Data, diagnosis: String?) {
    guard let report = try? JSONDecoder().decode(Report.self, from: reportJSON) else {
      return nil
    }
    self.init(report: report, diagnosis: diagnosis)
  }

  init(report: Report, diagnosis: String?) {
    let error = report.crash.error
    let type = Self.crashType(of: error)
    self.type = type
    message = Self.description(of: report, error: error, diagnosis: diagnosis)
      ?? "\(type) at \(Self.locationFrame(in: report).map(Self.moduleAndOffset) ?? "unknown location")"
  }

  private static func crashType(of error: CrashError) -> String {
    switch error.type {
    case .nsexception:
      return error.nsexception?.name ?? "NSException"
    case .cppException:
      return error.cppException?.name ?? "C++ exception"
    case .mach:
      if let exception = error.mach?.exceptionName {
        return error.signal?.name.map { "\(exception) (\($0))" } ?? exception
      }
    case .signal:
      if let signal = error.signal?.name {
        return signal
      }
    default:
      break
    }
    return error.type.rawValue
  }

  private static func description(of report: Report, error: CrashError, diagnosis: String?) -> String? {
    if let exception = error.nsexception {
      // KSCrash records an uncaught NSException's reason on the error itself.
      return nonEmpty(exception.reason ?? error.reason).map { "\(exception.name): \($0)" } ?? exception.name
    }
    if error.type == .cppException, let name = error.cppException?.name, let reason = nonEmpty(error.reason) {
      return "\(name): \(reason)"
    }
    return swiftRuntimeMessage(in: report)
      ?? nonEmpty(diagnosis.map(withoutUnknownFunction))
      ?? nonEmpty(error.reason)
  }

  /// KSCrash's diagnosis names the function it happened in, which Objective-C formats as `(null)`
  /// when the function is unknown, e.g. `Stack overflow in (null)`. Those clauses are dropped.
  private static func withoutUnknownFunction(_ diagnosis: String) -> String {
    diagnosis
      .replacingOccurrences(of: "\nOriginated at or in a subcall of (null)", with: "")
      .replacingOccurrences(of: " in (null)", with: "")
  }

  /// The `__crash_info` message the Swift runtime (or another library) left when it trapped, e.g.
  /// `File.swift:42: Fatal error: Unexpectedly found nil while unwrapping an Optional value`.
  /// Images on the crashed thread are preferred over any other image that recorded one.
  private static func swiftRuntimeMessage(in report: Report) -> String? {
    let images = report.binaryImages ?? []
    let crashedModules = Set(crashedFrames(in: report).compactMap(\.objectName))
    let onCrashedThread = images.filter { crashedModules.contains(lastPathComponent($0.name)) }
    return (onCrashedThread + images).lazy.compactMap { nonEmpty($0.crashInfoMessage) }.first
  }

  private static func crashedFrames(in report: Report) -> [StackFrame] {
    let thread = report.crash.threads?.first(where: \.crashed) ?? report.crash.crashedThread
    return thread?.backtrace?.contents ?? []
  }

  /// The first frame in the app's own binaries, which says more about the cause than a system
  /// library at the top of the stack; the crashed frame when no app frame is on the stack.
  private static func locationFrame(in report: Report) -> StackFrame? {
    let frames = crashedFrames(in: report)
    let appModules = Set((report.binaryImages ?? []).filter { $0.name.contains(".app/") }.map { lastPathComponent($0.name) })
    return frames.first { $0.objectName.map(appModules.contains) ?? false } ?? frames.first
  }

  /// `module + offset` from the start of the image, which is the same whether or not the frame was
  /// symbolicated on the device.
  private static func moduleAndOffset(_ frame: StackFrame) -> String {
    let module = frame.objectName ?? "unknown"
    guard let base = frame.objectAddr, frame.instructionAddr >= base else {
      return module
    }
    return "\(module) + \(frame.instructionAddr - base)"
  }

  private static func lastPathComponent(_ path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
  }

  private static func nonEmpty(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return nil
    }
    return trimmed
  }
}
