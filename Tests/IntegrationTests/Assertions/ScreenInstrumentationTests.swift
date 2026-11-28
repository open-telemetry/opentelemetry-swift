/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import OpenTelemetryApi
import ScreenInstrumentation
import XCTest

/// Checks the screen telemetry of the `main` launch, which needs no scenario of its own: a screen
/// appears on every launch.
///
/// Integration test mode runs offline, so `HackerNewsDemo` replaces the stories list with a bare
/// `UIViewController` in a disabled tab and selects the Settings tab instead. The only screen that
/// appears is therefore the SwiftUI one, marked with `otelScreen("Settings")`. The UIKit path is
/// covered by `ScreenTests` in the root package, which drives real view controllers.
///
/// Every key here comes from a registry, so a name that drifts from the registry fails here.
final class ScreenInstrumentationTests: XCTestCase {
  /// The screen integration test mode starts on.
  private static let firstScreen = "Settings"

  private var navigationEvents: [ExportedLog] {
    OTLPOutput.logs.filter {
      $0.record.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue
    }
  }

  private var timeToFirstDrawSpans: [ExportedSpan] {
    OTLPOutput.spans.filter {
      $0.span.name == FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue
    }
  }

  func testFirstScreenRecordsNavigationComplete() throws {
    let event = try XCTUnwrap(navigationEvents.first)
    XCTAssertEqual(event.scope.name, ScreenConstants.swiftUIScope)
    XCTAssertEqual(
      event.record.attributes.string(
        FederatedSemanticConventions.App.navigationDestinationName.rawValue),
      Self.firstScreen)
    XCTAssertEqual(
      event.record.attributes.string(FederatedSemanticConventions.App.screenType.rawValue),
      ScreenType.swiftui.attributeValue)
    XCTAssertGreaterThan(event.record.timeUnixNano, 0)
  }

  /// `ScreenLogRecordProcessor` stamps the current screen on the event as it is emitted, so the
  /// destination and the current screen agree.
  func testNavigationEventCarriesTheScreenName() throws {
    let event = try XCTUnwrap(navigationEvents.first)
    XCTAssertEqual(event.record.attributes.string(SemanticConventions.App.screenName.rawValue),
                   Self.firstScreen)
  }

  /// Nothing preceded the first screen, so the event must omit the previous screen rather than
  /// report an empty one.
  func testFirstNavigationHasNoPreviousScreen() throws {
    let event = try XCTUnwrap(navigationEvents.first)
    XCTAssertNil(
      event.record.attributes[FederatedSemanticConventions.App.screenPreviousName.rawValue])
  }

  func testFirstScreenRecordsTimeToFirstDraw() throws {
    let span = try XCTUnwrap(timeToFirstDrawSpans.first)
    XCTAssertEqual(span.scope.name, ScreenConstants.swiftUIScope)
    XCTAssertEqual(span.span.kind, .internal)
    XCTAssertEqual(span.span.attributes.string(SemanticConventions.App.screenName.rawValue),
                   Self.firstScreen)
    XCTAssertEqual(span.span.attributes.string(FederatedSemanticConventions.App.screenType.rawValue),
                   ScreenType.swiftui.attributeValue)
    XCTAssertGreaterThan(span.span.endTimeUnixNano, span.span.startTimeUnixNano)
  }

  /// One span per screen instance, so the launch records exactly one however long it runs.
  func testTimeToFirstDrawIsRecordedOncePerScreen() {
    XCTAssertEqual(timeToFirstDrawSpans.count, 1)
  }

  /// `ScreenSpanProcessor` stamps the current screen on every span that starts after a screen
  /// appeared, including spans from code that knows nothing about screens.
  func testScreenNameIsStampedOnLaterSpans() throws {
    let completion = try XCTUnwrap(OTLPOutput.spans.first {
      $0.scope.name == Scenario.scope && $0.span.name == Scenario.completionSpanName
    })
    XCTAssertEqual(completion.span.attributes.string(SemanticConventions.App.screenName.rawValue),
                   Self.firstScreen)
  }
}
