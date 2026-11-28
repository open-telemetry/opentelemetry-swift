/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// What `ScreenInstrumentationUIKit` reports.
public struct ScreenUIKitConfig: Sendable {
  /// The bundle a view controller's class must come from to be tracked. Defaults to the main
  /// bundle, which keeps the frameworks' own view controllers out of the data.
  public var bundle: Bundle

  /// Whether a screen records an `app.screen.time_to_first_draw` span. Applied to the tracker
  /// at install, so it reaches SwiftUI screens too.
  public var recordsTimeToFirstDraw: Bool

  /// Whether to report SwiftUI hosting controllers as UIKit screens. Off by default: the
  /// `.otelScreen` modifier names what a hosting controller hosts, and reporting both gives one
  /// view two screens. Turn it on to see SwiftUI screens without touching the views, accepting
  /// the hosting controller's class name as the screen name.
  public var tracksHostingControllers: Bool

  public init(bundle: Bundle = .main,
              recordsTimeToFirstDraw: Bool = true,
              tracksHostingControllers: Bool = false) {
    self.bundle = bundle
    self.recordsTimeToFirstDraw = recordsTimeToFirstDraw
    self.tracksHostingControllers = tracksHostingControllers
  }

  public static let `default` = ScreenUIKitConfig()
}
