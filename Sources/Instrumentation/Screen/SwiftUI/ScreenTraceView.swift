/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import Foundation
  import ScreenInstrumentation
  import OpenTelemetryApi
  import SwiftUI

  /// What the instrumentation remembers about one SwiftUI view identity, and what it does when
  /// that view appears.
  ///
  /// A class, so `onAppear` can record the first appearance without invalidating the view the
  /// way a mutated value in `@State` would. It also holds the reporting itself, which lets the
  /// tests exercise it without rendering anything.
  final class ScreenTraceState: @unchecked Sendable {
    /// When SwiftUI created the storage for this view identity, which starts the time to first
    /// appear. SwiftUI keeps the first instance it makes for an identity, so repeated
    /// initializations of the view struct do not move this.
    let loadTime: Date
    private var didReportFirstAppear = false

    init(loadTime: Date = Date()) {
      self.loadTime = loadTime
    }

    /// Reports the screen, then its first appearance.
    ///
    /// SwiftUI can call `onAppear` again for the same identity, so the span is reported once
    /// while the screen change is not: coming back to a screen is a navigation.
    func reportAppearance(screen: String,
                          attributes: [String: AttributeValue],
                          now: Date = Date(),
                          screenTracker: ScreenTracker? = nil) {
      let tracker = screenTracker ?? ScreenTrackerProvider.getInstance()
      tracker.setCurrent(screen: screen,
                         type: .swiftui,
                         timestamp: now,
                         attributes: attributes)

      guard !didReportFirstAppear else { return }
      didReportFirstAppear = true

      tracker.recordTimeToFirstAppear(screen: screen,
                                      type: .swiftui,
                                      loadTime: loadTime,
                                      appearTime: now,
                                      attributes: attributes)
    }
  }

  /// Reports its content as a screen: an `app.navigation.complete` event when it appears, and one
  /// `app.screen.time_to_first_appear` span measuring from the view's creation to that first
  /// appearance.
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
      content().onAppear {
        state.reportAppearance(screen: screenName, attributes: attributes)
      }
    }
  }
#endif
