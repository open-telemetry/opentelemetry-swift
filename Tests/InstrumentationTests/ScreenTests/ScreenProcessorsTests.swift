/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import ScreenInstrumentation
import XCTest

final class ScreenSpanProcessorTests: XCTestCase {
  private let screenNameKey = SemanticConventions.App.screenName.rawValue
  private var tracker: ScreenTracker!

  override func setUp() {
    super.setUp()
    ScreenTestFixtures.registerRecordingProviders()
    tracker = ScreenTracker()
  }

  func testWantsStartsAndNotEnds() {
    let processor = ScreenSpanProcessor(screenTracker: tracker)
    XCTAssertTrue(processor.isStartRequired)
    XCTAssertFalse(processor.isEndRequired)
  }

  func testAddsTheCurrentScreenName() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    let span = StubReadableSpan()

    ScreenSpanProcessor(screenTracker: tracker).onStart(parentContext: nil, span: span)

    XCTAssertEqual(ScreenTestFixtures.string(span.capturedAttributes[screenNameKey]), "Stories")
  }

  func testAddsNothingBeforeAnyScreenAppears() {
    let span = StubReadableSpan()

    ScreenSpanProcessor(screenTracker: tracker).onStart(parentContext: nil, span: span)

    XCTAssertNil(span.capturedAttributes[screenNameKey])
  }

  func testKeepsAScreenNameTheProducerAlreadySet() {
    tracker.setCurrent(screen: "Stories", type: .uikit)
    let span = StubReadableSpan()
    span.setAttribute(key: screenNameKey, value: .string("Comments"))

    ScreenSpanProcessor(screenTracker: tracker).onStart(parentContext: nil, span: span)

    XCTAssertEqual(ScreenTestFixtures.string(span.capturedAttributes[screenNameKey]), "Comments")
  }
}

final class ScreenLogRecordProcessorTests: XCTestCase {
  private let screenNameKey = SemanticConventions.App.screenName.rawValue
  private var tracker: ScreenTracker!
  private var next: RecordingLogRecordProcessor!
  private var processor: ScreenLogRecordProcessor!

  override func setUp() {
    super.setUp()
    ScreenTestFixtures.registerRecordingProviders()
    tracker = ScreenTracker()
    next = RecordingLogRecordProcessor()
    processor = ScreenLogRecordProcessor(nextProcessor: next, screenTracker: tracker)
  }

  func testAddsTheCurrentScreenName() {
    tracker.setCurrent(screen: "Stories", type: .uikit)

    processor.onEmit(logRecord: ScreenTestFixtures.logRecord())

    XCTAssertEqual(next.records.count, 1)
    XCTAssertEqual(ScreenTestFixtures.string(next.records.first?.attributes[screenNameKey]), "Stories")
  }

  func testForwardsUntouchedBeforeAnyScreenAppears() {
    processor.onEmit(logRecord: ScreenTestFixtures.logRecord(attributes: ["k": .string("v")]))

    XCTAssertEqual(next.records.count, 1)
    XCTAssertNil(next.records.first?.attributes[screenNameKey])
    XCTAssertEqual(ScreenTestFixtures.string(next.records.first?.attributes["k"]), "v")
  }

  func testKeepsAScreenNameTheProducerAlreadySet() {
    tracker.setCurrent(screen: "Stories", type: .uikit)

    processor.onEmit(logRecord: ScreenTestFixtures.logRecord(attributes: [screenNameKey: .string("Comments")]))

    XCTAssertEqual(ScreenTestFixtures.string(next.records.first?.attributes[screenNameKey]), "Comments")
  }

  func testForwardsShutdownAndFlush() {
    XCTAssertEqual(processor.shutdown(explicitTimeout: nil), .success)
    XCTAssertEqual(processor.forceFlush(explicitTimeout: nil), .success)
    XCTAssertEqual(next.shutdownCount, 1)
    XCTAssertEqual(next.forceFlushCount, 1)
  }
}

final class ScreenTrackerProviderTests: XCTestCase {
  func testReturnsTheRegisteredTracker() {
    let tracker = ScreenTracker()
    ScreenTrackerProvider.register(screenTracker: tracker)

    XCTAssertTrue(ScreenTrackerProvider.getInstance() === tracker)
  }

  func testReturnsTheSameInstanceOnRepeatedReads() {
    let first = ScreenTrackerProvider.getInstance()
    XCTAssertTrue(ScreenTrackerProvider.getInstance() === first)
  }
}
