/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import OpenTelemetryApi
  import SwiftUI

  @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
  public extension SwiftUI.View {
    /// Reports this view as a screen named `screenName`.
    ///
    /// ```swift
    /// SettingsView()
    ///   .otelScreen("Settings")
    /// ```
    ///
    /// - Parameters:
    ///   - screenName: A stable name for the screen. Choose one that will still mean the same
    ///     thing on a dashboard in six months.
    ///   - attributes: Extra attributes for the `app.navigation.complete` event and the
    ///     `app.screen.time_to_first_draw` span.
    func otelScreen(_ screenName: String,
                    attributes: [String: AttributeValue] = [:]) -> some SwiftUI.View {
      ScreenTraceView(screenName, attributes: attributes) { self }
    }
  }
#endif
