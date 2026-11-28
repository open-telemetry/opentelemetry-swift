/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import InstrumentationSemanticConventions
import OpenTelemetryApi
import ScreenInstrumentation
import XCTest

/// Checks the navigation stack against the `screen-navigation` launch, which drives a UIKit flow
/// presented over the SwiftUI Settings tab, then a SwiftUI navigation stack presented over it.
/// Keep the steps in sync with `ScreenNavigationScenario` in the demo app.
final class ScreenNavigationTests: XCTestCase {
  private struct Navigation: Equatable, CustomStringConvertible {
    let destination: String?
    let type: String?
    let screenType: String?

    var description: String {
      "\(destination ?? "nil") \(type ?? "-") (\(screenType ?? "nil"))"
    }
  }

  private static let uikit = ScreenType.uikit.attributeValue
  private static let swiftui = ScreenType.swiftui.attributeValue

  /// One event per step, in sequence order.
  private static let expected: [Navigation] = [
    Navigation(destination: "Settings", type: "initial", screenType: swiftui),
    // UIKit flow, presented as a page sheet over Settings.
    Navigation(destination: "NavProbeListViewController", type: "modal", screenType: uikit),
    Navigation(destination: "NavProbeDetailViewController", type: "push", screenType: uikit),
    Navigation(destination: "NavProbeAuthorViewController", type: "push", screenType: uikit),
    Navigation(destination: "NavProbeListViewController", type: "pop_to", screenType: uikit),
    Navigation(destination: "NavProbeDetailViewController", type: "push", screenType: uikit),
    Navigation(destination: "NavProbeListViewController", type: "pop", screenType: uikit),
    Navigation(destination: "NavProbeDetailViewController", type: "push", screenType: uikit),
    Navigation(destination: "NavProbeAuthorViewController", type: "replace", screenType: uikit),
    Navigation(destination: "NavProbeLoginViewController", type: "reset", screenType: uikit),
    // A page sheet's presenter gets no viewDidAppear, and it is a SwiftUI screen.
    Navigation(destination: "Settings", type: "dismiss", screenType: swiftui),
    // SwiftUI stack in a presented hosting controller. Its presentation is UIKit's, so the
    // SwiftUI front end sees only a new screen.
    Navigation(destination: "Probe List", type: "push", screenType: swiftui),
    Navigation(destination: "Probe Detail", type: "push", screenType: swiftui),
    Navigation(destination: "Probe Author", type: "push", screenType: swiftui),
    Navigation(destination: "Probe List", type: "pop_to", screenType: swiftui),
    Navigation(destination: "Probe Detail", type: "push", screenType: swiftui),
    Navigation(destination: "Probe List", type: "pop", screenType: swiftui),
    Navigation(destination: "Probe Detail", type: "push", screenType: swiftui),
    Navigation(destination: "Probe Author", type: "replace", screenType: swiftui),
    Navigation(destination: "Probe Detail", type: "push", screenType: swiftui),
    Navigation(destination: "Probe Login", type: "reset", screenType: swiftui),
    Navigation(destination: "Probe Sheet", type: "modal", screenType: swiftui),
    Navigation(destination: "Probe Login", type: "dismiss", screenType: swiftui),
  ]

  private var events: [ExportedLog] {
    OTLPOutput.launch(.screenNavigation).logs
      .filter { $0.record.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue }
      .sorted {
        ($0.record.attributes.int(FederatedSemanticConventions.App.navigationSequence.rawValue) ?? 0)
          < ($1.record.attributes.int(FederatedSemanticConventions.App.navigationSequence.rawValue) ?? 0)
      }
  }

  func testEachStepReportsItsDestinationAndType() {
    let observed = events.map { event in
      Navigation(destination: event.record.attributes.string(FederatedSemanticConventions.App.navigationDestinationName.rawValue),
                 type: event.record.attributes.string(FederatedSemanticConventions.App.navigationType.rawValue),
                 screenType: event.record.attributes.string(FederatedSemanticConventions.App.screenType.rawValue))
    }
    XCTAssertEqual(observed, Self.expected,
                   "observed:\n" + observed.map(\.description).joined(separator: "\n"))
  }

  /// The walk stays in one session, so its numbers run 1, 2, 3 with no gap.
  func testSequenceNumbersRunUnbroken() {
    let sequences = events.compactMap {
      $0.record.attributes.int(FederatedSemanticConventions.App.navigationSequence.rawValue)
    }
    XCTAssertEqual(sequences, Array(1 ... Int64(sequences.count)))
    XCTAssertEqual(sequences.count, Self.expected.count)
  }

  /// Each event names the screen it left, so the journey can be rebuilt from the events alone.
  func testEachEventNamesTheScreenItLeft() {
    let destinations = events.map {
      $0.record.attributes.string(FederatedSemanticConventions.App.navigationDestinationName.rawValue)
    }
    let previous = events.map {
      $0.record.attributes.string(FederatedSemanticConventions.App.screenPreviousName.rawValue)
    }
    XCTAssertEqual(Array(previous.dropFirst()), Array(destinations.dropLast()))
  }
}
