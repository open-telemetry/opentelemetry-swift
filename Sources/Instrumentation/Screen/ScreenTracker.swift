/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import InstrumentationSemanticConventions
import OpenTelemetryApi

/// Holds the name of the screen the user is looking at, and reports each change.
///
/// One tracker serves the whole process. The UIKit and SwiftUI instrumentations feed it, and
/// `ScreenSpanProcessor` and `ScreenLogRecordProcessor` read it to stamp `app.screen.name` on
/// every span and log record. Applications that navigate by neither path call
/// `setCurrent(screen:type:)` themselves.
///
/// A change does three things, in this order: it records the transition, it emits one
/// `app.navigation.complete` event, and it posts `ScreenChangeNotification`. Setting the same
/// name again does nothing, so a screen that reappears without an intervening screen produces no
/// second event.
public final class ScreenTracker: @unchecked Sendable {
  /// Guards `_currentScreen` and `_previousScreen` so a transition is atomic.
  private let lock = NSLock()
  private var _currentScreen: String?
  private var _previousScreen: String?
  private var _recordsTimeToFirstAppear: Bool

  /// - Parameter recordsTimeToFirstAppear: Whether `recordTimeToFirstAppear` records a span.
  ///   Defaults to `true`.
  public init(recordsTimeToFirstAppear: Bool = true) {
    _recordsTimeToFirstAppear = recordsTimeToFirstAppear
  }

  /// Whether a screen records an `app.screen.time_to_first_appear` span.
  ///
  /// The tracker holds this rather than either front end, so turning it off reaches UIKit and
  /// SwiftUI alike. Set it before the first screen appears.
  public var recordsTimeToFirstAppear: Bool {
    get { lock.withLock { _recordsTimeToFirstAppear } }
    set { lock.withLock { _recordsTimeToFirstAppear = newValue } }
  }

  /// The screen the user is looking at, or `nil` before the first screen appears.
  public var currentScreen: String? {
    lock.withLock { _currentScreen }
  }

  /// The screen that was visible before `currentScreen`.
  public var previousScreen: String? {
    lock.withLock { _previousScreen }
  }

  /// Records that `screen` is now visible.
  ///
  /// - Parameters:
  ///   - screen: The new screen name. Ignored when it already is the current screen.
  ///   - type: The UI framework that drew it.
  ///   - timestamp: When the screen appeared. Defaults to now.
  ///   - logger: Where to emit `app.navigation.complete`. Defaults to the scope for `type`.
  ///   - attributes: Extra attributes for the event.
  public func setCurrent(screen: String,
                         type: ScreenType,
                         timestamp: Date = Date(),
                         logger: Logger? = nil,
                         attributes: [String: AttributeValue] = [:]) {
    let transition: (changed: Bool, previous: String?) = lock.withLock {
      guard _currentScreen != screen else { return (false, nil) }
      _previousScreen = _currentScreen
      _currentScreen = screen
      return (true, _previousScreen)
    }
    guard transition.changed else { return }

    emitNavigationComplete(screen: screen,
                           previousScreen: transition.previous,
                           type: type,
                           timestamp: timestamp,
                           logger: logger ?? Self.logger(for: type),
                           attributes: attributes)

    NotificationCenter.default.post(name: ScreenChangeNotification, object: screen)
  }

  /// Emits one `app.navigation.complete` event, matching `opentelemetry-android`.
  ///
  /// `app.screen.name` is not set here. The current screen is already this one, so
  /// `ScreenLogRecordProcessor` stamps it, and an application running without that processor
  /// still gets the destination name.
  private func emitNavigationComplete(screen: String,
                                      previousScreen: String?,
                                      type: ScreenType,
                                      timestamp: Date,
                                      logger: Logger,
                                      attributes: [String: AttributeValue]) {
    var eventAttributes = attributes
    eventAttributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue] = .string(screen)
    eventAttributes[FederatedSemanticConventions.App.screenType.rawValue] = .string(type.attributeValue)
    if let previousScreen {
      eventAttributes[FederatedSemanticConventions.App.screenPreviousName.rawValue] = .string(previousScreen)
    }

    logger.logRecordBuilder()
      .setEventName(FederatedSemanticConventions.EventName.appNavigationComplete.rawValue)
      .setTimestamp(timestamp)
      .setAttributes(eventAttributes)
      .emit()
  }

  static func logger(for type: ScreenType) -> Logger {
    let scope = type == .uikit ? ScreenConstants.uiKitScope : ScreenConstants.swiftUIScope
    return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: scope)
  }

  static func tracer(for type: ScreenType) -> Tracer {
    let scope = type == .uikit ? ScreenConstants.uiKitScope : ScreenConstants.swiftUIScope
    return OpenTelemetry.instance.tracerProvider.get(instrumentationName: scope)
  }

  /// Records one `app.screen.time_to_first_appear` span, from a screen's creation to its first
  /// appearance.
  ///
  /// The caller owns the "first" part: it must call this once per screen instance. UIKit keeps
  /// that flag on the view controller, SwiftUI in `@State`, so two windows showing the same
  /// screen each report their own span.
  public func recordTimeToFirstAppear(screen: String,
                                      type: ScreenType,
                                      loadTime: Date,
                                      appearTime: Date,
                                      attributes: [String: AttributeValue] = [:]) {
    guard recordsTimeToFirstAppear else { return }

    let builder = Self.tracer(for: type)
      .spanBuilder(spanName: FederatedSemanticConventions.SpanName.appScreenTimeToFirstAppear.rawValue)
      .setStartTime(time: loadTime)
      .setAttribute(key: SemanticConventions.App.screenName.rawValue, value: screen)
      .setAttribute(key: FederatedSemanticConventions.App.screenType.rawValue, value: type.attributeValue)

    for (key, value) in attributes {
      builder.setAttribute(key: key, value: value)
    }

    builder.startSpan().end(time: appearTime)
  }
}
