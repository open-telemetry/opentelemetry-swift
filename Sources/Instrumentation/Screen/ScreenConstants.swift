/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Names this instrumentation emits that no semantic convention registry defines.
///
/// The attribute, span and event names come from registries instead:
/// `SemanticConventions.App.screenName` for `app.screen.name`, which upstream defines, and
/// `FederatedSemanticConventions` for the rest, generated from
/// `Sources/Instrumentation/SemanticConventions/model/swift/screen.yaml` and `screen-spans.yaml`.
public enum ScreenConstants {
  /// Instrumentation scope for screens detected through UIKit.
  public static let uiKitScope = "io.opentelemetry.screen.uikit"

  /// Instrumentation scope for screens traced through the SwiftUI modifiers.
  public static let swiftUIScope = "io.opentelemetry.screen.swiftui"

  /// Notification posted when the current screen changes. The object is the new screen name.
  public static let screenChangeNotification = "ScreenTracker.ScreenChange"
}

/// Posted when the current screen changes. The notification object is the new screen name.
public let ScreenChangeNotification = Notification.Name(ScreenConstants.screenChangeNotification)
