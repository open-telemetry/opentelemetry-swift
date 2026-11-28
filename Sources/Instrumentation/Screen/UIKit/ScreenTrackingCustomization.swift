/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(UIKit) && !os(watchOS)
  import UIKit

  /// Lets a view controller name itself, or stay out of the telemetry.
  ///
  /// Without it, a view controller in the configured bundle is tracked under its class name.
  ///
  /// ```swift
  /// final class LoginViewController: UIViewController, ScreenTrackingCustomization {
  ///   var customScreenName: String? { "Login" }
  /// }
  ///
  /// final class DebugViewController: UIViewController, ScreenTrackingCustomization {
  ///   var tracksScreen: Bool { false }
  /// }
  /// ```
  @MainActor
  public protocol ScreenTrackingCustomization {
    /// The name to report instead of the class name, or `nil` to use the class name.
    var customScreenName: String? { get }

    /// Whether to report this view controller at all. Return `false` for a screen that shows
    /// sensitive content, or one that exists only to pass the user along.
    var tracksScreen: Bool { get }
  }

  public extension ScreenTrackingCustomization where Self: UIViewController {
    var customScreenName: String? { nil }

    var tracksScreen: Bool { true }
  }
#endif
