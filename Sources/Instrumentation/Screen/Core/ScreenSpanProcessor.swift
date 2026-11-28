/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adds `app.screen.name` to every span, naming the screen the user was looking at when the span
/// started.
///
/// The attribute is set at start, not at end, so a span that outlives a navigation keeps the
/// screen that produced it. A span that already carries `app.screen.name` is left alone: its
/// producer knew better.
public class ScreenSpanProcessor: SpanProcessor {
  public var isStartRequired = true
  public var isEndRequired = false

  private let screenTracker: ScreenTracker

  /// - Parameter screenTracker: The tracker to read. Defaults to the shared one.
  public init(screenTracker: ScreenTracker? = nil) {
    self.screenTracker = screenTracker ?? ScreenTrackerProvider.getInstance()
  }

  public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let key = SemanticConventions.App.screenName.rawValue
    guard let screen = screenTracker.currentScreen,
          span.getAttributes()[key] == nil else { return }
    span.setAttribute(key: key, value: screen)
  }

  public func onEnd(span: ReadableSpan) {}

  public func shutdown(explicitTimeout: TimeInterval?) {}

  public func forceFlush(timeout: TimeInterval?) {}
}
