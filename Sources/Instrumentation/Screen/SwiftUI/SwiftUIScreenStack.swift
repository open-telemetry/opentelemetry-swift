/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import Foundation
  import OpenTelemetryApi
  import ScreenInstrumentation

  /// The SwiftUI screens on screen, in the order they appeared, and the navigation each change
  /// makes.
  ///
  /// SwiftUI reports no navigation, only each view's `onAppear` and `onDisappear`, and does not
  /// order one view's `onDisappear` against the next view's `onAppear`. Two facts make the stack
  /// readable anyway. A covered view keeps its `@State`, so its `ScreenTraceState` stays alive; a
  /// removed view's state is freed, in the same moment as its own `onDisappear`. And that
  /// `onDisappear` arrives well after the revealed view's `onAppear`: about half a second on a pop.
  /// So a brand-new screen is a push at once, but a screen that reappears waits for the removal,
  /// and the number of screens freed tells a pop from a pop to an earlier screen.
  ///
  /// Main thread only, like the SwiftUI callbacks that feed it.
  final class SwiftUIScreenStack: @unchecked Sendable {
    static let shared = SwiftUIScreenStack()

    /// How long after an `onDisappear` to look for freed states. A main-loop turn is not enough:
    /// the state can outlive the callback by a few milliseconds.
    static let removalCheckDelay: TimeInterval = 0.1

    /// How long a reappearing screen waits for a removal before it reports anyway. A cancelled
    /// interactive pop hides the revealed screen again after about 0.9 seconds.
    static let revealFallbackDelay: TimeInterval = 1.0

    /// How long a navigation type from an opt-in modifier waits for the screen change it labels. A
    /// pop or dismissal is decided about 0.6 seconds after the state changes.
    static let expectationLifetime: TimeInterval = 2.0

    private final class Entry {
      weak var state: ScreenTraceState?
      let screen: String
      let attributes: [String: AttributeValue]
      var isVisible = true

      init(state: ScreenTraceState, screen: String, attributes: [String: AttributeValue]) {
        self.state = state
        self.screen = screen
        self.attributes = attributes
      }
    }

    private var entries: [Entry] = []
    private weak var current: ScreenTraceState?
    private var expectation: (type: NavigationType, deadline: Date)?
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void

    /// - Parameter schedule: Runs a block after a delay. Defaults to the main queue.
    init(schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }) {
      self.schedule = schedule
    }

    /// Labels the next screen change with `type`, as an opt-in modifier does when it sees the
    /// change before the views do.
    func expect(_ type: NavigationType, now: Date = Date()) {
      expectation = (type, now.addingTimeInterval(Self.expectationLifetime))
    }

    /// Records that the view holding `state` appeared.
    func appear(_ state: ScreenTraceState,
                screen: String,
                attributes: [String: AttributeValue],
                now: Date,
                tracker: ScreenTracker) {
      guard tracker.tracksNavigation else {
        tracker.setCurrent(screen: screen, type: .swiftui, timestamp: now, attributes: attributes)
        return
      }

      if let index = entries.firstIndex(where: { $0.state === state }) {
        let entry = entries.remove(at: index)
        entry.isVisible = true
        entries.append(entry)
        reveal(entry, now: now, tracker: tracker)
        return
      }

      let entry = Entry(state: state, screen: screen, attributes: attributes)
      entries.append(entry)
      // The tracker labels the first screen of the process `initial`.
      let navigation = consumeExpectation(now: now) ?? (tracker.currentScreen == nil ? nil : .push)
      report(entry, navigation: navigation, now: now, tracker: tracker)
    }

    /// Records that the view holding `state` disappeared, and checks shortly after whether it was
    /// removed or only covered.
    func disappear(_ state: ScreenTraceState, now: Date, tracker: ScreenTracker) {
      guard tracker.tracksNavigation,
            let entry = entries.first(where: { $0.state === state }) else { return }
      entry.isVisible = false
      schedule(Self.removalCheckDelay) { [weak self] in
        self?.resolve(now: now, tracker: tracker)
      }
    }

    /// Reports the top visible screen if it changed, with the kind of navigation the freed
    /// screens show.
    func resolve(now: Date, tracker: ScreenTracker) {
      let removed = entries.filter { $0.state == nil }.count
      entries.removeAll { $0.state == nil }

      guard let top = entries.last(where: { $0.isVisible }),
            let topState = top.state,
            topState !== current else { return }

      let navigation = consumeExpectation(now: now) ?? Self.navigation(removing: removed)
      report(top, navigation: navigation, now: now, tracker: tracker)
    }

    /// The kind of navigation that removing `count` screens makes.
    static func navigation(removing count: Int) -> NavigationType? {
      switch count {
      case ..<1: nil
      case 1: .pop
      default: .popTo
      }
    }

    private func reveal(_ entry: Entry, now: Date, tracker: ScreenTracker) {
      guard let state = entry.state else { return }
      if state === current, tracker.currentScreen == entry.screen { return }

      // Nothing SwiftUI will leave: the current SwiftUI screen is gone, or a UIKit or manual
      // screen took over since. Report at once.
      if current == nil || tracker.currentScreen != currentScreenName {
        report(entry, navigation: consumeExpectation(now: now), now: now, tracker: tracker)
        return
      }
      schedule(Self.revealFallbackDelay) { [weak self] in
        self?.resolve(now: now, tracker: tracker)
      }
    }

    private var currentScreenName: String? {
      entries.first { $0.state === current }?.screen
    }

    private func report(_ entry: Entry, navigation: NavigationType?, now: Date, tracker: ScreenTracker) {
      current = entry.state
      tracker.setCurrent(screen: entry.screen,
                         type: .swiftui,
                         navigation: navigation,
                         timestamp: now,
                         attributes: entry.attributes)
    }

    private func consumeExpectation(now: Date) -> NavigationType? {
      defer { expectation = nil }
      guard let expectation, expectation.deadline >= now else { return nil }
      return expectation.type
    }
  }
#endif
