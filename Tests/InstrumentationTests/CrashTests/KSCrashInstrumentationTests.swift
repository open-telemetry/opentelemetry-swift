/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
import OpenTelemetrySdk
import OpenTelemetryApi
@testable import Sessions
@testable import Crash

#if canImport(KSCrash)
  import KSCrash
#endif

final class KSCrashInstrumentationTests: XCTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    NotificationCenter.default.removeObserver(self)
    super.tearDown()
  }

  func testCacheCrashContext() {
    let session = Session(
      id: "cache-session-id",
      expireTime: Date(timeIntervalSinceNow: 1800),
      previousId: "cache-prev-id"
    )

    KSCrashInstrumentation.cacheCrashContext(session: session)

    let userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[SemanticConventions.Session.id.rawValue], "cache-session-id")
    XCTAssertEqual(userInfo?[SemanticConventions.Session.previousId.rawValue], "cache-prev-id")
  }

  func testReporterConfiguration() {
    XCTAssertNotNil(KSCrashInstrumentation.reporter)
  }

  func testMaxStackTraceBytes() {
    XCTAssertEqual(KSCrashInstrumentation.maxStackTraceBytes, 25 * 1024)
  }

  func testExtractCrashMessageWithExceptionType() {
    let stackTrace = """
    Exception Type:  EXC_BREAKPOINT (SIGTRAP)
    Thread 0 Crashed:
    0   libswiftCore.dylib            0x000000019ed5c8c4 $ss17_assertionFailure + 172
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "EXC_BREAKPOINT (SIGTRAP) detected on thread 0 at libswiftCore.dylib + 172")
  }

  func testExtractCrashMessageWithBadAccess() {
    let stackTrace = """
    Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
    Thread 2 Crashed:
    0   MyApp                         0x0000000104abc123 main + 456
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "EXC_BAD_ACCESS (SIGSEGV) detected on thread 2 at MyApp + 456")
  }

  func testExtractCrashMessageWithoutExceptionType() {
    let stackTrace = """
    Thread 0 Crashed:
    0   libswiftCore.dylib            0x000000019ed5c8c4 $ss17_assertionFailure + 172
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "Unknown exception detected on thread 0 at libswiftCore.dylib + 172")
  }

  func testExtractCrashMessageWithDifferentThread() {
    let stackTrace = """
    Exception Type:  EXC_CRASH (SIGABRT)
    Thread 5 Crashed:
    0   SomeFramework                 0x00000001f14e1a90 someFunction + 8
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "EXC_CRASH (SIGABRT) detected on thread 5 at SomeFramework + 8")
  }

  func testExtractCrashMessageEdgeCases() {
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: ""), "Unknown exception detected at unknown location")
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: "Thread Crashed:\n0   SomeFramework"), "Unknown exception detected at unknown location")

    let noThreadCrashed = "Some other content\nThread 1:\n0   libsystem_kernel.dylib"
    XCTAssertEqual(KSCrashInstrumentation.extractCrashMessage(from: noThreadCrashed), "Unknown exception detected at unknown location")
  }

  func testExtractCrashMessageWithWhitespaceHandling() {
    let stackTrace = """
    Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
    Thread 2 Crashed:
    0     MyFramework     \t\t\t    0x123456789    myFunction    +    123
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "EXC_BAD_ACCESS (SIGSEGV) detected on thread 2 at MyFramework + 123")
  }

  func testExtractCrashMessageWithExceptionTypeOnly() {
    let stackTrace = """
    Exception Type:  EXC_CRASH (SIGABRT)
    """

    let result = KSCrashInstrumentation.extractCrashMessage(from: stackTrace)
    XCTAssertEqual(result, "EXC_CRASH (SIGABRT) detected at unknown location")
  }

  func testRecoverCrashContextSuccess() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [:]

    let rawCrash: [String: Any] = [
      "report": ["timestamp": "2025-10-28T21:38:55.554842Z"],
      "user": [
        SemanticConventions.Session.id.rawValue: "test-session-id",
        SemanticConventions.Session.previousId.rawValue: "test-prev-session-id"
      ]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result[SemanticConventions.Session.id.rawValue]?.description, "test-session-id")
    XCTAssertEqual(result[SemanticConventions.Session.previousId.rawValue]?.description, "test-prev-session-id")
  }

  func testRecoverCrashContextNoSessionId() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [:]

    let result = KSCrashInstrumentation.recoverCrashContext(from: [:], log: mockLogBuilder, attributes: initialAttributes)
    XCTAssertNil(result[SemanticConventions.Session.id.rawValue])
  }

  func testRecoverCrashContextMissingPreviousSessionId() {
    let mockLogBuilder = MockLogRecordBuilder()
    let initialAttributes: [String: AttributeValue] = [:]

    let rawCrash: [String: Any] = [
      "report": ["timestamp": "2025-10-28T21:38:55.554842Z"],
      "user": [SemanticConventions.Session.id.rawValue: "test-session-id"]
    ]

    let result = KSCrashInstrumentation.recoverCrashContext(
      from: rawCrash,
      log: mockLogBuilder,
      attributes: initialAttributes
    )

    XCTAssertEqual(result[SemanticConventions.Session.id.rawValue]?.description, "test-session-id")
    XCTAssertNil(result[SemanticConventions.Session.previousId.rawValue])
  }

  func testNotificationHandling() {
    KSCrashInstrumentation.setupNotificationObservers()
    defer {
      for observer in KSCrashInstrumentation.observers {
        NotificationCenter.default.removeObserver(observer)
      }
      KSCrashInstrumentation.observers.removeAll()
    }

    let session = Session(id: "notification-session", expireTime: Date(timeIntervalSinceNow: 1800))
    NotificationCenter.default.post(name: Notification.Name(SessionConstants.sessionEventNotification), object: session)

    let expectation = XCTestExpectation(description: "Async crash context update")
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)

    let userInfo = KSCrashInstrumentation.reporter.userInfo as? [String: String]
    XCTAssertEqual(userInfo?[SemanticConventions.Session.id.rawValue], "notification-session")
  }

  func testInstallMethod() {
    XCTAssertFalse(KSCrashInstrumentation.isInstalled)
    XCTAssertNoThrow(KSCrashInstrumentation.install())
    XCTAssertTrue(KSCrashInstrumentation.isInstalled)
  }

  func testProcessStoredCrashes() {
    XCTAssertNoThrow(KSCrashInstrumentation.processStoredCrashes())
  }
}

class MockLogRecordBuilder: LogRecordBuilder {
  var timestamp: Date?
  var attributes: [String: AttributeValue] = [:]
  var eventName: String?

  func setTimestamp(_ timestamp: Date) -> LogRecordBuilder {
    self.timestamp = timestamp
    return self
  }

  func setObservedTimestamp(_ timestamp: Date) -> LogRecordBuilder { return self }
  func setEventName(_ name: String) -> LogRecordBuilder {
    eventName = name
    return self
  }

  func setSeverity(_ severity: Severity) -> LogRecordBuilder { return self }
  func setBody(_ body: AttributeValue) -> LogRecordBuilder { return self }
  func setAttributes(_ attributes: [String: AttributeValue]) -> LogRecordBuilder {
    self.attributes = attributes
    return self
  }

  func addAttribute(key: String, value: AttributeValue) -> LogRecordBuilder {
    attributes[key] = value
    return self
  }

  func emit() {}
}
