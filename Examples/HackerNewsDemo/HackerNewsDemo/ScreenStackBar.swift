/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Combine
import InstrumentationSemanticConventions
import OpenTelemetryApi
import OpenTelemetrySdk
import ScreenInstrumentation
import SwiftUI
import UIKit

/// The navigation stack as the screen instrumentation reports it.
///
/// The tracker keeps only the current and previous screen, so this rebuilds the stack from each
/// `app.navigation.complete` event and its `app.navigation.type`. Each tab keeps its own stack;
/// a `switch` stashes the one being left and restores the one whose top is the destination.
final class ScreenStackModel: ObservableObject {
  static let shared = ScreenStackModel()

  private static let barEnabledKey = "HackerNewsDemo.ScreenStackBar.enabled"

  struct Screen: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let navigation: NavigationType?
  }

  @Published private(set) var stack: [Screen] = []
  /// The type of the latest navigation, which can differ from the top entry's: a pop reveals
  /// an entry that was pushed.
  @Published private(set) var lastNavigation: NavigationType?
  @Published var isBarEnabled: Bool {
    didSet { UserDefaults.standard.set(isBarEnabled, forKey: Self.barEnabledKey) }
  }

  private var stashedStacks: [[Screen]] = []

  private init() {
    isBarEnabled = UserDefaults.standard.bool(forKey: Self.barEnabledKey)
  }

  func apply(destination: String, navigation: NavigationType?) {
    let screen = Screen(name: destination, navigation: navigation)
    lastNavigation = navigation
    switch navigation {
    case .push, .modal:
      stack.append(screen)
    case .pop, .dismiss:
      if !stack.isEmpty { stack.removeLast() }
      reveal(screen)
    case .popTo:
      reveal(screen)
    case .replace:
      if !stack.isEmpty { stack.removeLast() }
      stack.append(screen)
    case .initial, .reset:
      stack = [screen]
    default:
      // `switch`, or no type: the first screen, or an event the front end could not classify.
      if stack.last?.name == destination { return }
      switchStack(to: screen)
    }
  }

  /// Truncates to the last entry named like `screen`, or starts over from it if none is.
  private func reveal(_ screen: Screen) {
    if let index = stack.lastIndex(where: { $0.name == screen.name }) {
      stack.removeSubrange((index + 1)...)
    } else {
      stack.append(screen)
    }
  }

  private func switchStack(to screen: Screen) {
    if !stack.isEmpty { stashedStacks.append(stack) }
    if let index = stashedStacks.lastIndex(where: { $0.last?.name == screen.name }) {
      stack = stashedStacks.remove(at: index)
    } else {
      stack = [screen]
    }
  }
}

/// Feeds `ScreenStackModel` from the `app.navigation.complete` events the tracker emits.
final class ScreenStackLogRecordProcessor: LogRecordProcessor {
  func onEmit(logRecord: ReadableLogRecord) {
    guard logRecord.eventName == FederatedSemanticConventions.EventName.appNavigationComplete.rawValue,
          case let .string(destination)? =
          logRecord.attributes[FederatedSemanticConventions.App.navigationDestinationName.rawValue] else {
      return
    }
    var navigation: NavigationType?
    if case let .string(value)? = logRecord.attributes[FederatedSemanticConventions.App.navigationType.rawValue] {
      navigation = NavigationType.allCases.first { $0.attributeValue == value }
    }
    DispatchQueue.main.async {
      ScreenStackModel.shared.apply(destination: destination, navigation: navigation)
    }
  }

  func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }

  func shutdown(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

/// A floating bar naming the current screen and the navigation that reached it. Tap it to show
/// the whole stack.
struct ScreenStackBar: SwiftUI.View {
  @ObservedObject var model = ScreenStackModel.shared
  @State private var isExpanded = false

  static func color(for navigation: NavigationType?) -> Color {
    switch navigation {
    case .push, .modal: .green
    case .pop, .popTo, .dismiss: .orange
    case .replace, .reset: .purple
    case .switch: .blue
    case .initial, nil: .gray
    }
  }

  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "rectangle.stack")
        Text(model.stack.last?.name ?? "No screen yet")
          .fontWeight(.semibold)
          .lineLimit(1)
        Spacer(minLength: 4)
        Text(model.lastNavigation?.attributeValue ?? "none")
          .foregroundColor(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Self.color(for: model.lastNavigation), in: Capsule())
        Text("\(model.stack.count)")
          .foregroundColor(.secondary)
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .foregroundColor(.secondary)
      }
      if isExpanded {
        Divider()
        ForEach(Array(model.stack.enumerated().reversed()), id: \.element.id) { index, screen in
          HStack(spacing: 6) {
            Text("\(index)")
              .foregroundColor(.secondary)
              .frame(width: 18, alignment: .trailing)
            Text(screen.name)
              .fontWeight(index == model.stack.count - 1 ? .semibold : .regular)
              .lineLimit(1)
            Spacer(minLength: 4)
            Text(screen.navigation?.attributeValue ?? "—")
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .font(.system(.caption, design: .monospaced))
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 4)
    .padding(.horizontal, 12)
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
    }
    .animation(.easeInOut(duration: 0.2), value: model.stack)
  }
}

/// A window above the app that shows `ScreenStackBar` and passes every other touch through.
///
/// A separate window keeps the bar above sheets, and keeps it out of the app's own view
/// controller hierarchy, so the screen instrumentation never reports it.
final class ScreenStackBarWindow: UIWindow {
  private var cancellable: AnyCancellable?
  /// The bar's frame in window coordinates. Touches outside it reach the app beneath.
  private var barFrame: CGRect = .zero

  override init(windowScene: UIWindowScene) {
    super.init(windowScene: windowScene)
    windowLevel = .alert + 1
    backgroundColor = .clear

    let host = UIHostingController(rootView: ScreenStackBarContainer { [weak self] frame in
      self?.barFrame = frame
    })
    host.view.backgroundColor = .clear
    rootViewController = host

    cancellable = ScreenStackModel.shared.$isBarEnabled
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isEnabled in self?.isHidden = !isEnabled }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // SwiftUI handles touches in the hosting view itself, so the view a hit test returns cannot
  // tell the bar from the empty space around it; the bar's frame can.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    barFrame.contains(point) ? super.hitTest(point, with: event) : nil
  }
}

private struct ScreenStackBarContainer: SwiftUI.View {
  let onBarFrameChange: (CGRect) -> Void

  var body: some SwiftUI.View {
    VStack {
      ScreenStackBar()
        .background(GeometryReader { proxy in
          Color.clear
            .onAppear { onBarFrameChange(proxy.frame(in: .global)) }
            .onChange(of: proxy.frame(in: .global)) { onBarFrameChange($0) }
        })
      Spacer()
    }
    .padding(.top, 52)
  }
}
