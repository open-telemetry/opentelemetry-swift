/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ScreenInstrumentation
import Sessions
import XCTest

final class NavigationSequenceTests: XCTestCase {
  private var logs: RecordingLogRecordProcessor!
  private var persistence: InMemorySessionPersistence!
  private var sessionManager: SessionManager!
  private var suiteName: String!
  private var defaults: UserDefaults!

  override func setUpWithError() throws {
    try super.setUpWithError()
    logs = ScreenTestFixtures.registerRecordingProviders().logs
    persistence = InMemorySessionPersistence()
    sessionManager = try SessionManager(persistence: persistence)
    suiteName = "NavigationSequenceTests.\(UUID().uuidString)"
    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  func testFirstNavigationInASessionIsOne() {
    makeTracker().setCurrent(screen: "Stories", type: .uikit)

    XCTAssertEqual(sequences(), [1])
  }

  func testNumbersEachNavigationInOrder() {
    let tracker = makeTracker()
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)
    tracker.setCurrent(screen: "Stories", type: .swiftui)

    XCTAssertEqual(sequences(), [1, 2, 3])
  }

  func testSettingTheSameScreenUsesNoNumber() {
    let tracker = makeTracker()
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)

    XCTAssertEqual(sequences(), [1, 2])
  }

  func testStartsAgainAtOneInANewSession() {
    let tracker = makeTracker()
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)

    sessionManager.resetSession()
    tracker.setCurrent(screen: "Settings", type: .uikit)

    XCTAssertEqual(sequences(), [1, 2, 1])
  }

  func testContinuesAcrossARestartThatResumesTheSession() throws {
    let tracker = makeTracker()
    tracker.setCurrent(screen: "Stories", type: .uikit)
    tracker.setCurrent(screen: "Comments", type: .uikit)
    let sessionId = sessionManager.getSession().id

    let relaunchedManager = try SessionManager(persistence: persistence)
    XCTAssertEqual(relaunchedManager.getSession().id, sessionId)
    ScreenTracker(sessionManager: relaunchedManager, userDefaults: defaults)
      .setCurrent(screen: "Stories", type: .uikit)

    XCTAssertEqual(sequences(), [1, 2, 3])
  }

  func testKeepsOneKeyAcrossSessions() {
    let tracker = makeTracker()
    for screen in ["Stories", "Comments", "Settings"] {
      tracker.setCurrent(screen: screen, type: .uikit)
      sessionManager.resetSession()
    }

    let keys = defaults.persistentDomain(forName: suiteName)?.keys.sorted() ?? []
    XCTAssertEqual(keys, [NavigationSequence.defaultsKey])
  }

  func testCountsTheSessionTheEventIsStampedWith() throws {
    let recording = RecordingLogRecordProcessor()
    OpenTelemetry.registerLoggerProvider(loggerProvider: LoggerProviderBuilder()
      .with(processors: [SessionLogRecordProcessor(nextProcessor: recording, sessionManager: sessionManager)])
      .build())
    let tracker = makeTracker()
    tracker.setCurrent(screen: "Stories", type: .uikit)
    sessionManager.resetSession()
    tracker.setCurrent(screen: "Comments", type: .uikit)

    let events = recording.records.filter {
      $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue
    }
    XCTAssertEqual(events.count, 2)
    let sessionIds = events.map { ScreenTestFixtures.string($0.attributes[SemanticConventions.Session.id.rawValue]) }
    XCTAssertNotNil(sessionIds[0])
    XCTAssertNotEqual(sessionIds[0], sessionIds[1])
    XCTAssertEqual(events.map { sequence($0) }, [1, 1])
  }

  func testConcurrentChangesNumberTransitionsInOrder() {
    let tracker = makeTracker()
    let names = (0 ..< 200).map { "Screen\($0)" }
    let group = DispatchGroup()
    for name in names {
      DispatchQueue.global().async(group: group) {
        tracker.setCurrent(screen: name, type: .uikit)
      }
    }
    group.wait()

    let events = logs.records
      .filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
      .sorted { (sequence($0) ?? 0) < (sequence($1) ?? 0) }
    let expectedSequences: [Int?] = Array(1 ... names.count)
    XCTAssertEqual(events.map { sequence($0) }, expectedSequences)

    // Read in sequence order, each event leaves the screen the one before it entered.
    let destinations = events.map {
      ScreenTestFixtures.string($0.attributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue])
    }
    let previousNames = events.map {
      ScreenTestFixtures.string($0.attributes[FederatedSemanticConventions.App.screenPreviousName.rawValue])
    }
    XCTAssertEqual(previousNames, [nil] + destinations.dropLast())
  }

  // MARK: - Helpers

  private func makeTracker() -> ScreenTracker {
    ScreenTracker(sessionManager: sessionManager, userDefaults: defaults)
  }

  private func sequences() -> [Int?] {
    logs.records
      .filter { $0.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
      .map { sequence($0) }
  }

  private func sequence(_ record: ReadableLogRecord) -> Int? {
    guard case let .int(value)? = record.attributes[FederatedSemanticConventions.App.navigationSequence.rawValue] else {
      return nil
    }
    return value
  }
}

/// Holds a session record in memory, so a second manager over it acts like a relaunch.
private final class InMemorySessionPersistence: SessionPersistence, @unchecked Sendable {
  private let lock = NSLock()
  private var data: Data?

  func read() -> Data? { lock.withLock { data } }

  func write(_ data: Data) -> Bool {
    lock.withLock { self.data = data }
    return true
  }

  func clear() -> Bool {
    lock.withLock { data = nil }
    return true
  }
}
