/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import InstrumentationSemanticConventions

/// The UI framework that drew a screen, reported as `app.screen.type`.
///
/// UIKit screens come from swizzled view controller lifecycle methods, so their boundaries are
/// exact. SwiftUI screens come from `onAppear`, which fires per view identity and can fire more
/// than once. Consumers compare timings only within one type.
public enum ScreenType: String, Sendable, CaseIterable {
  case uikit
  case swiftui

  /// The value this type reports as `app.screen.type`, from the federated registry.
  public var attributeValue: String {
    switch self {
    case .uikit: FederatedSemanticConventions.App.ScreenTypeValues.uikit.description
    case .swiftui: FederatedSemanticConventions.App.ScreenTypeValues.swiftui.description
    }
  }
}
