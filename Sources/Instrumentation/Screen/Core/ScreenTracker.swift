/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import InstrumentationSemanticConventions
import OpenTelemetryApi
import Sessions

/// Holds the name of the screen the user is looking at, and reports each change.
///
/// One tracker serves the whole process. The UIKit and SwiftUI instrumentations feed it, and
/// `ScreenSpanProcessor` and `ScreenLogRecordProcessor` read it to stamp `app.screen.name` on
/// every span and log record. Applications that navigate by neither path call
/// `setCurrent(screen:)` themselves, which reports the screen as `manual`.
///
/// A change does three things, in this order: it records the transition, it emits one
/// `app.navigation.complete` event, and it posts `ScreenChangeNotification`. Setting the same
/// name again without a navigation type does nothing, so a screen that reappears without an
/// intervening screen produces no second event. A front end that knows the kind of navigation
/// passes it, and the event is emitted even when the name repeats, because a push of a second
/// instance of the same screen is still a navigation.
///
/// Each event carries `app.navigation.sequence`, its position within the current session. The
/// tracker reads the session from the same `SessionManager` that `SessionLogRecordProcessor`
/// stamps `session.id` from, so the two agree.
public final class ScreenTracker: @unchecked Sendable {
  /// Guards `_currentScreen` and `_previousScreen` so a transition is atomic.
  private let lock = NSLock()
  /// Serializes a transition with the number it takes, so numbers rise in transition order.
  /// Recursive because the session read and the `UserDefaults` write run while it is held, and
  /// either can call observers on this thread that set the screen again.
  private let transitionLock = NSRecursiveLock()
  private var _currentScreen: String?
  private var _previousScreen: String?
  private var _currentScreenType: ScreenType?
  private var _recordsTimeToFirstDraw: Bool
  private var _tracksNavigation: Bool
  private let sessionManager: SessionManager?
  private let navigationSequence: NavigationSequence

  /// - Parameters:
  ///   - recordsTimeToFirstDraw: Whether `recordTimeToFirstDraw` records a span.
  ///     Defaults to `true`.
  ///   - tracksNavigation: Whether the front ends follow the navigation stack and report
  ///     `app.navigation.type`. Defaults to `true`.
  ///   - sessionManager: The session that numbers navigations. Defaults to
  ///     `SessionManagerProvider.getInstance()`, read at each navigation.
  ///   - userDefaults: Where the navigation count persists across restarts. Defaults to
  ///     `.standard`. The tracker writes one key there.
  public init(recordsTimeToFirstDraw: Bool = true,
              tracksNavigation: Bool = true,
              sessionManager: SessionManager? = nil,
              userDefaults: UserDefaults = .standard) {
    _recordsTimeToFirstDraw = recordsTimeToFirstDraw
    _tracksNavigation = tracksNavigation
    self.sessionManager = sessionManager
    navigationSequence = NavigationSequence(defaults: userDefaults)
  }

  /// Whether a screen records an `app.screen.time_to_first_draw` span.
  ///
  /// The tracker holds this rather than either front end, so turning it off reaches UIKit and
  /// SwiftUI alike. Set it before the first screen appears.
  public var recordsTimeToFirstDraw: Bool {
    get { lock.withLock { _recordsTimeToFirstDraw } }
    set { lock.withLock { _recordsTimeToFirstDraw = newValue } }
  }

  /// Whether the front ends follow the navigation stack and report `app.navigation.type`.
  ///
  /// On by default. Turned off, the current screen is the last one to appear, a dismissed sheet
  /// leaves its name behind, and no event carries a navigation type. The UIKit front end reads
  /// this at install, so set it before installing.
  public var tracksNavigation: Bool {
    get { lock.withLock { _tracksNavigation } }
    set { lock.withLock { _tracksNavigation = newValue } }
  }

  /// The screen the user is looking at, or `nil` before the first screen appears.
  public var currentScreen: String? {
    lock.withLock { _currentScreen }
  }

  /// What reported `currentScreen`, or `nil` before the first screen appears.
  public var currentScreenType: ScreenType? {
    lock.withLock { _currentScreenType }
  }

  /// The screen that was visible before `currentScreen`.
  public var previousScreen: String? {
    lock.withLock { _previousScreen }
  }

  /// Records that `screen` is now visible.
  ///
  /// - Parameters:
  ///   - screen: The new screen name. Ignored when it already is the current screen.
  ///   - type: What reported it. Defaults to `.manual`, for a screen the application reports
  ///     itself; the UIKit and SwiftUI front ends pass their own type.
  ///   - navigation: How the user got there, when known. Ignored when `tracksNavigation` is
  ///     off. With a value, the event is emitted even if `screen` is already current.
  ///   - timestamp: When the screen appeared. Defaults to now.
  ///   - logger: Where to emit `app.navigation.complete`. Defaults to the scope for `type`.
  ///   - attributes: Extra attributes for the event.
  public func setCurrent(screen: String,
                         type: ScreenType = .manual,
                         navigation: NavigationType? = nil,
                         timestamp: Date = Date(),
                         logger: Logger? = nil,
                         attributes: [String: AttributeValue] = [:]) {
    let numbered: (previous: String?, sequence: Int, navigation: NavigationType?)? = transitionLock.withLock {
      let transition: (changed: Bool, previous: String?, navigation: NavigationType?) = lock.withLock {
        // The first screen of the process is `initial` unless the caller says otherwise.
        let navigation = _tracksNavigation ? navigation ?? (_currentScreen == nil ? .initial : nil) : nil
        guard _currentScreen != screen || navigation != nil else { return (false, nil, nil) }
        _previousScreen = _currentScreen
        _currentScreen = screen
        _currentScreenType = type
        return (true, _previousScreen, navigation)
      }
      guard transition.changed else { return nil }

      // Read outside `lock`: starting a session emits events that `ScreenLogRecordProcessor`
      // stamps by reading `currentScreen`, which takes `lock`. Taking the number outside it
      // keeps the `UserDefaults` write, and the observers it notifies, off `lock` too.
      let session = (sessionManager ?? SessionManagerProvider.getInstance()).getSession()
      return (transition.previous, navigationSequence.next(sessionId: session.id), transition.navigation)
    }
    guard let numbered else { return }

    emitNavigationComplete(screen: screen,
                           previousScreen: numbered.previous,
                           sequence: numbered.sequence,
                           navigation: numbered.navigation,
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
                                      sequence: Int,
                                      navigation: NavigationType?,
                                      type: ScreenType,
                                      timestamp: Date,
                                      logger: Logger,
                                      attributes: [String: AttributeValue]) {
    var eventAttributes = attributes
    eventAttributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue] = .string(screen)
    eventAttributes[FederatedSemanticConventions.App.screenType.rawValue] = .string(type.attributeValue)
    eventAttributes[FederatedSemanticConventions.App.navigationSequence.rawValue] = .int(sequence)
    if let previousScreen {
      eventAttributes[FederatedSemanticConventions.App.screenPreviousName.rawValue] = .string(previousScreen)
    }
    if let navigation {
      eventAttributes[FederatedSemanticConventions.App.navigationType.rawValue] = .string(navigation.attributeValue)
    }

    logger.logRecordBuilder()
      .setEventName(FederatedSemanticConventions.EventName.appNavigationComplete.rawValue)
      .setTimestamp(timestamp)
      .setAttributes(eventAttributes)
      .emit()
  }

  static func logger(for type: ScreenType) -> Logger {
    OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: type.scope)
  }

  static func tracer(for type: ScreenType) -> Tracer {
    OpenTelemetry.instance.tracerProvider.get(instrumentationName: type.scope)
  }

  /// Records one `app.screen.time_to_first_draw` span, from a screen's creation to the first
  /// frame that displayed it.
  ///
  /// The caller owns the "first" part: it must call this once per screen instance. UIKit keeps
  /// that flag on the view controller, SwiftUI in `@State`, so two windows showing the same
  /// screen each report their own span.
  public func recordTimeToFirstDraw(screen: String,
                                    type: ScreenType,
                                    loadTime: Date,
                                    drawTime: Date,
                                    attributes: [String: AttributeValue] = [:]) {
    guard recordsTimeToFirstDraw else { return }

    let builder = Self.tracer(for: type)
      .spanBuilder(spanName: FederatedSemanticConventions.SpanName.appScreenTimeToFirstDraw.rawValue)
      .setStartTime(time: loadTime)
      .setAttribute(key: SemanticConventions.App.screenName.rawValue, value: screen)
      .setAttribute(key: FederatedSemanticConventions.App.screenType.rawValue, value: type.attributeValue)

    for (key, value) in attributes {
      builder.setAttribute(key: key, value: value)
    }

    builder.startSpan().end(time: drawTime)
  }
}
