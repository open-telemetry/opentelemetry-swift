/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import InstrumentationSemanticConventions

/// How a navigation reached its destination, reported as `app.navigation.type`.
///
/// A front end sets it only when it can tell. See each front end's README for which kinds it
/// detects.
public enum NavigationType: String, Sendable, CaseIterable {
  /// The first screen of the process; nothing was current before it.
  case initial
  /// A new screen was added on top of the current one.
  case push
  /// The current screen was removed, revealing the one directly beneath it.
  case pop
  /// Several screens were removed at once, revealing an earlier one.
  case popTo
  /// The current screen was swapped for a new one; the screens beneath it stayed.
  case replace
  /// Every screen was replaced, leaving the new one alone.
  case reset
  /// A screen was presented modally over the current one, such as a sheet or a full-screen cover.
  case modal
  /// A presented screen was dismissed, revealing the screen that presented it.
  case dismiss
  /// An existing screen became current without any screen being removed, such as a tab change.
  case `switch`

  /// The value this type reports as `app.navigation.type`, from the federated registry.
  public var attributeValue: String {
    switch self {
    case .initial: FederatedSemanticConventions.App.NavigationTypeValues.initial.description
    case .push: FederatedSemanticConventions.App.NavigationTypeValues.push.description
    case .pop: FederatedSemanticConventions.App.NavigationTypeValues.pop.description
    case .popTo: FederatedSemanticConventions.App.NavigationTypeValues.popTo.description
    case .replace: FederatedSemanticConventions.App.NavigationTypeValues.replace.description
    case .reset: FederatedSemanticConventions.App.NavigationTypeValues.reset.description
    case .modal: FederatedSemanticConventions.App.NavigationTypeValues.modal.description
    case .dismiss: FederatedSemanticConventions.App.NavigationTypeValues.dismiss.description
    case .switch: FederatedSemanticConventions.App.NavigationTypeValues.switch.description
    }
  }
}
