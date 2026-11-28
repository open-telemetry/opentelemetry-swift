/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import Combine
  import Foundation
  import InstrumentationCommon
  import ScreenInstrumentation
  import OpenTelemetryApi
  import SwiftUI
  #if canImport(UIKit) && !os(watchOS)
    import UIKit
  #endif

  /// What the instrumentation remembers about one SwiftUI view identity, and what it does when
  /// that view appears.
  ///
  /// A class, so `onAppear` can start the first draw without invalidating the view the way a
  /// mutated value in `@State` would. It also holds the reporting itself, which lets the tests
  /// exercise it without rendering anything.
  final class ScreenTraceState: @unchecked Sendable {
    /// When the `ScreenTraceView` value SwiftUI kept for this identity was built, which starts the
    /// time to first draw. `@State` builds a new instance with every view value, and SwiftUI keeps
    /// the one from the value it inserts, so later rebuilds do not move this.
    let loadTime: Date
    private var didStartFirstDraw = false
    private var pendingDraw: FirstFrameRead?

    init(loadTime: Date = Date()) {
      self.loadTime = loadTime
    }

    /// The reader that ends the span, or `nil` where no display link exists, which ends it at
    /// `onAppear` instead.
    static var defaultFirstFrameReader: FirstFrameReader? {
      #if canImport(UIKit) && !os(watchOS)
        DisplayLinkFirstFrameReader()
      #else
        nil
      #endif
    }

    /// Reports the screen, then waits for its first draw.
    ///
    /// SwiftUI can call `onAppear` again for the same identity, so the span is reported once
    /// while the screen change is not: coming back to a screen is a navigation. `onAppear`
    /// completes before the first rendered frame, so the span ends at the next frame displayed.
    func reportAppearance(screen: String,
                          attributes: [String: AttributeValue],
                          now: Date = Date(),
                          screenTracker: ScreenTracker? = nil,
                          firstFrameReader: FirstFrameReader? = ScreenTraceState.defaultFirstFrameReader) {
      let tracker = screenTracker ?? ScreenTrackerProvider.getInstance()
      tracker.setCurrent(screen: screen,
                         type: .swiftui,
                         timestamp: now,
                         attributes: attributes)

      guard !didStartFirstDraw else { return }
      didStartFirstDraw = true

      let loadTime = loadTime
      guard let firstFrameReader else {
        tracker.recordTimeToFirstDraw(screen: screen,
                                      type: .swiftui,
                                      loadTime: loadTime,
                                      drawTime: now,
                                      attributes: attributes)
        return
      }

      var isDone = false
      let read = firstFrameReader.readFirstFrame { [weak self] drawTime in
        isDone = true
        self?.pendingDraw = nil
        tracker.recordTimeToFirstDraw(screen: screen,
                                      type: .swiftui,
                                      loadTime: loadTime,
                                      drawTime: drawTime,
                                      attributes: attributes)
      }
      if !isDone {
        pendingDraw = read
      }
    }

    /// Drops a read still waiting for a frame. A display link pauses in the background, so a read
    /// left running would end at a frame drawn after the user came back.
    func cancelPendingDraw() {
      pendingDraw?.cancel()
      pendingDraw = nil
    }
  }

  /// Reports its content as a screen: an `app.navigation.complete` event when it appears, and one
  /// `app.screen.time_to_first_draw` span measuring from the view's creation to the first frame
  /// that displayed it.
  ///
  /// Use the `otelScreen(_:attributes:)` modifier instead unless you need the wrapper form.
  ///
  /// Apply it to a screen, not to a row or a label. Every appearance sets the current screen, so
  /// a view that appears while another screen is on top will take the name over.
  @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
  public struct ScreenTraceView<Content: SwiftUI.View>: SwiftUI.View {
    @State private var state = ScreenTraceState()

    private let screenName: String
    private let attributes: [String: AttributeValue]
    private let content: () -> Content

    /// - Parameters:
    ///   - screenName: A stable name for the screen, such as `"Settings"`.
    ///   - attributes: Extra attributes for the event and the span.
    ///   - content: The screen.
    public init(_ screenName: String,
                attributes: [String: AttributeValue] = [:],
                @SwiftUI.ViewBuilder content: @escaping () -> Content) {
      self.screenName = screenName
      self.attributes = attributes
      self.content = content
    }

    public var body: some SwiftUI.View {
      content()
        .onAppear {
          state.reportAppearance(screen: screenName, attributes: attributes)
        }
      #if canImport(UIKit) && !os(watchOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
          state.cancelPendingDraw()
        }
      #endif
    }
  }
#endif
