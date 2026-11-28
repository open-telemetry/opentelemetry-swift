/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import OpenTelemetryApi
@testable import ScreenInstrumentation
import XCTest

/// Pins the names this instrumentation puts on the wire.
///
/// The instrumentation and the rest of these tests both read the generated constants, so a rename
/// in the registry would pass every other test while breaking every consumer's query. These
/// assertions spell the names out instead.
final class ScreenSemanticConventionsTests: XCTestCase {
  func testScreenNameComesFromUpstream() {
    XCTAssertEqual(SemanticConventions.App.screenName.rawValue, "app.screen.name")
  }

  func testNavigationCompleteEventName() {
    XCTAssertEqual(FederatedSemanticConventions.EventName.appNavigationComplete.rawValue,
                   "app.navigation.complete")
  }

  func testTimeToFirstDrawSpanName() {
    XCTAssertEqual(FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue,
                   "app.screen.time_to_first_draw")
  }

  func testAttributeNames() {
    XCTAssertEqual(FederatedSemanticConventions.App.navigationDestinationName.rawValue,
                   "app.navigation.destination.name")
    XCTAssertEqual(FederatedSemanticConventions.App.screenPreviousName.rawValue,
                   "app.screen.previous.name")
    XCTAssertEqual(FederatedSemanticConventions.App.screenType.rawValue, "app.screen.type")
  }

  func testScreenTypeValuesMatchTheRegistry() {
    XCTAssertEqual(ScreenType.uikit.attributeValue, "uikit")
    XCTAssertEqual(ScreenType.swiftui.attributeValue, "swiftui")
    XCTAssertEqual(ScreenType.allCases.map(\.attributeValue), ["uikit", "swiftui"])
  }

  func testInstrumentationScopes() {
    XCTAssertEqual(ScreenConstants.uiKitScope, "io.opentelemetry.screen.uikit")
    XCTAssertEqual(ScreenConstants.swiftUIScope, "io.opentelemetry.screen.swiftui")
  }
}
