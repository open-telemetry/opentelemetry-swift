/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

#if canImport(KSCrashRecording)
  import KSCrashRecording
#elseif canImport(KSCrash)
  import KSCrash
#endif

#if canImport(KSCrashFilters)
  import KSCrashFilters
#endif

import Sessions

public class KSCrashInstrumentationConfig: KSCrashConfiguration {
  public var maxStackTraceBytes: Int = 25 * 1024
  /// On-device symbolication is best-effort and tends to diverge from
  /// backend-produced symbolication, which makes it a poor source for
  /// crash grouping. Default `false`; backends should symbolicate.
  public var useOnDeviceSymbolication: Bool = false

  public static let `default` = KSCrashInstrumentationConfig()

  override public init() {
    super.init()
    // SIGTERM is rarely a real crash signal in iOS lifecycles.
    enableSigTermMonitoring = false
    // Swap C++ throw improves C++ traces but adds launch cost; users with
    // C++-heavy apps can re-enable.
    enableSwapCxaThrow = false
  }
}

public class KSCrashInstrumentation: Instrumentation {
  public private(set) static var isInstalled: Bool = false
  public internal(set) static var maxStackTraceBytes = 25 * 1024
  static let reporter = KSCrash.shared
  static var observers: [NSObjectProtocol] = []

  // Single serial queue is the only writer of `reporter.userInfo` and the
  // only mutator of `observers`. Anything that touches that state must hop
  // onto this queue.
  private static let queue = DispatchQueue(label: "io.opentelemetry.kscrash", qos: .utility)
  // Covers the install() check-then-set on `isInstalled`.
  private static let installLock = NSLock()
  private static var installedConfig: KSCrashInstrumentationConfig = .default
  private static let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: "io.opentelemetry.kscrash")
  private static let timestampFormatter: ISO8601DateFormatter = {
    // Example KSCrash timestamp: `2025-10-28T03:30:53.604204Z`
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime,
      .withFractionalSeconds
    ]
    return formatter
  }()

  public init(config: KSCrashInstrumentationConfig = .default) {
    super.init(scope: "io.opentelemetry.kscrash")
    Self.install(config: config)
  }

  /// Installs KSCrash if not already installed. Idempotent and thread-safe.
  /// Subsequent work (caching context, processing stored crashes,
  /// registering observers) is dispatched onto `queue`.
  public static func install(config: KSCrashInstrumentationConfig = .default) {
    installLock.lock()
    defer { installLock.unlock() }
    guard !isInstalled else {
      return
    }

    do {
      try reporter.install(with: config)
      installedConfig = config
      maxStackTraceBytes = config.maxStackTraceBytes
      isInstalled = true
    } catch {
      return
    }

    // Hand off remaining setup to the serial queue so all later writes to
    // `reporter.userInfo` and `observers` happen from the same context.
    queue.async {
      cacheCrashContext()
      processStoredCrashes()
      setupNotificationObservers()
    }
  }

  /// Must run on `queue`. Mutates static `observers`.
  static func setupNotificationObservers() {
    // Update crash context on session start
    let sessionObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(SessionConstants.sessionEventNotification),
      object: nil,
      queue: nil
    ) { notification in
      if let session = notification.object as? Session {
        queue.async {
          cacheCrashContext(session: session)
        }
      }
    }
    observers.append(sessionObserver)
  }

  /// Must run on `queue`. Sole writer of `reporter.userInfo`.
  static func cacheCrashContext(session: Session? = nil) {
    var userInfo: [String: Any] = [:]

    let sessionManager = SessionManagerProvider.getInstance()
    if let session = session ?? sessionManager.peekSession() {
      userInfo[SemanticConventions.Session.id.rawValue] = session.id
      if let prevSessionId = session.previousId {
        userInfo[SemanticConventions.Session.previousId.rawValue] = prevSessionId
      }
    }

    reporter.userInfo = userInfo
  }

  /// Report cached crashes from KSCrash store (just a local file).
  /// Must run on `queue`.
  static func processStoredCrashes() {
    guard let reportStore = reporter.reportStore else {
      return
    }

    // Pull crash reports
    let reportIDs = reportStore.reportIDs
    for reportID in reportIDs {
      guard let id = reportID as? Int64,
            let crashReport = reportStore.report(for: id) else {
        continue
      }

      // Report crash as log event
      reportCrash(crashReport: crashReport)
      // Delete processed report
      reportStore.deleteReport(with: id)
    }
  }

  // Report a KSCrash report in Apple format
  private static func reportCrash(crashReport: CrashReportDictionary) {
    let rawCrash: [String: Any] = crashReport.value
    let log: any LogRecordBuilder = logger.logRecordBuilder()
      .setEventName("device.crash")

    var attributes: [String: AttributeValue] = [
      SemanticConventions.Exception.type.rawValue: AttributeValue.string("crash")
    ]

    // Attempt to recover the original crash context
    attributes = recoverCrashContext(from: rawCrash, log: log, attributes: attributes)

    // Get stack trace in Apple format and emit log event in async callback.
    // On-device symbolication is opt-in: it is best-effort, varies with
    // optimization level, and can split groupings vs. backend symbolication.
    let style: AppleReportStyle = installedConfig.useOnDeviceSymbolication ? .symbolicated : .unsymbolicated
    let filter = CrashReportFilterAppleFmt(reportStyle: style)
    filter.filterReports([crashReport]) { reports, _ in
      var appleFormatReport = (reports?.first as? CrashReportString)?.value ?? "Failed to format crash report"
      if appleFormatReport.utf8.count > maxStackTraceBytes {
        appleFormatReport = String(appleFormatReport.utf8.prefix(maxStackTraceBytes)) ?? appleFormatReport
      }
      attributes[SemanticConventions.Exception.stacktrace.rawValue] = AttributeValue.string(appleFormatReport)

      // `Crash detected on thread 0 at libswiftCore.dylib 0x000000019ed5c8c4 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172`
      attributes[SemanticConventions.Exception.message.rawValue] = AttributeValue.string(extractCrashMessage(from: appleFormatReport))

      _ = log.setAttributes(attributes)
      log.emit()
    }
  }

  /// Get exception code information for the crash message. This is useful for grouping
  static func extractCrashMessage(from stackTrace: String) -> String {
    let lines = stackTrace.components(separatedBy: "\n")

    // Get exception type
    let exceptionType = lines.first(where: { $0.hasPrefix("Exception Type:") })?
      .replacingOccurrences(of: "Exception Type:", with: "")
      .trimmingCharacters(in: .whitespaces) ?? "Unknown exception"

    // Fallback to thread and first frame
    guard let crashedLine = lines.first(where: { $0.range(of: #"Thread \d+ Crashed:"#, options: .regularExpression) != nil }),
          let threadMatch = crashedLine.range(of: #"Thread (\d+) Crashed:"#, options: .regularExpression),
          let crashedIndex = lines.firstIndex(of: crashedLine),
          let firstFrame = lines.dropFirst(crashedIndex + 1).first(where: { $0.hasPrefix("0   ") }) else {
      return "\(exceptionType) detected at unknown location"
    }

    let threadNumber = String(crashedLine[threadMatch]).replacingOccurrences(of: #"Thread (\d+) Crashed:"#, with: "$1", options: .regularExpression)

    // Extract module and offset (skip instruction pointer which is unique per crash and breaks grouping)
    // Frame format: "0   ModuleName   0x00000001dccb1658   0x1dccab000 + 26200"
    //                    ^module      ^instruction pointer  ^base addr   ^offset
    let frameComponents = firstFrame.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    guard frameComponents.count >= 4,
          let module = frameComponents.dropFirst().first,
          let offset = frameComponents.last else {
      return "\(exceptionType) detected on thread \(threadNumber) at unknown location"
    }

    return "\(exceptionType) detected on thread \(threadNumber) at \(module) + \(offset)"
  }

  /// If sessionId and timestamp can be recovered, then attempt to restore original context.
  /// However, if user session context cannot be recovered, then we use the current timestamp
  /// and let sessions id processors do their work. For this edge case, users can look
  /// at the current `session.previous_id` to see if the previous session had crashed.
  static func recoverCrashContext(from rawCrash: [String: Any],
                                  log: LogRecordBuilder,
                                  attributes: [String: AttributeValue]) -> [String: AttributeValue] {
    guard let report = rawCrash["report"] as? [String: Any],
          let timestampString = report["timestamp"] as? String,
          let timestamp = timestampFormatter.date(from: timestampString),
          let userInfo = rawCrash["user"] as? [String: Any],
          let sessionId = userInfo[SemanticConventions.Session.id.rawValue] as? String else {
      _ = log.setTimestamp(Date())
      return attributes
    }
    var mutatedAttributes = attributes

    // required attributes for recovery
    _ = log.setTimestamp(timestamp)
    mutatedAttributes[SemanticConventions.Session.id.rawValue] = AttributeValue.string(sessionId)

    // `session.previous_id` is also nice-to-have, and may not even exist if there was no previous session
    if let previousSessionId = userInfo[SemanticConventions.Session.previousId.rawValue] as? String {
      mutatedAttributes[SemanticConventions.Session.previousId.rawValue] = AttributeValue.string(previousSessionId)
    }

    return mutatedAttributes
  }
}
