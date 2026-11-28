/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import InstrumentationSemanticConventions

/// What reported a screen, reported as `app.screen.type`.
///
/// UIKit screens come from swizzled view controller lifecycle methods, so their boundaries are
/// exact. SwiftUI screens come from `onAppear`, which fires per view identity and can fire more
/// than once. Manual screens come from the application calling `setCurrent` itself.
public enum ScreenType: String, Sendable, CaseIterable {
  case uikit
  case swiftui
  case manual

  /// The value this type reports as `app.screen.type`, from the federated registry.
  public var attributeValue: String {
    switch self {
    case .uikit: FederatedSemanticConventions.App.ScreenTypeValues.uikit.description
    case .swiftui: FederatedSemanticConventions.App.ScreenTypeValues.swiftui.description
    case .manual: FederatedSemanticConventions.App.ScreenTypeValues.manual.description
    }
  }

  /// The instrumentation scope this type reports under.
  var scope: String {
    switch self {
    case .uikit: ScreenConstants.uiKitScope
    case .swiftui: ScreenConstants.swiftUIScope
    case .manual: ScreenConstants.manualScope
    }
  }
}
