/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(SwiftUI)
  import ScreenInstrumentation
  import SwiftUI

  // SwiftUI's own callbacks cannot tell a replace or reset from a push, a sheet from a push, or a
  // tab change from a pop. The app's navigation state can. Each modifier below watches that state
  // with `onChange`, which sees every change, whether the app or SwiftUI made it, before the
  // destination view appears. It labels the screen change the views then report.

  @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
  public extension View {
    /// Labels changes to a `NavigationStack` path: push, pop, pop_to, replace or reset.
    ///
    /// ```swift
    /// NavigationStack(path: $path) { ... }
    ///   .otelNavigationPath(path)
    /// ```
    ///
    /// A replace or reset that keeps the destination view's type reuses the view, so SwiftUI
    /// reports no change at all. Give each destination `.id(route)` so the change reaches the
    /// screen tracker.
    func otelNavigationPath<Element: Equatable>(_ path: [Element]) -> some View {
      modifier(NavigationChangeModifier(value: path, stack: .shared, classify: SwiftUIScreenStack.navigation(from:to:)))
    }

    /// Labels a sheet or full-screen cover: modal when `isPresented` becomes `true`, dismiss when
    /// it becomes `false`, whether the app or a swipe changes it.
    ///
    /// ```swift
    /// .sheet(isPresented: $showsSettings) { ... }
    /// .otelModal(showsSettings)
    /// ```
    func otelModal(_ isPresented: Bool) -> some View {
      modifier(NavigationChangeModifier(value: isPresented, stack: .shared, classify: SwiftUIScreenStack.navigation(presenting:to:)))
    }

    /// Labels a sheet or full-screen cover shown for an optional item: modal when the item is set,
    /// dismiss when it is cleared.
    ///
    /// ```swift
    /// .sheet(item: $selectedStory) { story in ... }
    /// .otelModal(item: selectedStory)
    /// ```
    func otelModal<Item>(item: Item?) -> some View {
      otelModal(item != nil)
    }

    /// Labels a change of `TabView` selection as a switch.
    ///
    /// ```swift
    /// TabView(selection: $tab) { ... }
    ///   .otelTabSelection(tab)
    /// ```
    func otelTabSelection<Selection: Equatable>(_ selection: Selection) -> some View {
      modifier(NavigationChangeModifier(value: selection, stack: .shared, classify: SwiftUIScreenStack.navigation(selecting:to:)))
    }
  }

  /// Remembers a navigation value and labels each change of it.
  final class NavigationChangeObserver<Value: Equatable> {
    private var previous: Value
    private let stack: SwiftUIScreenStack
    private let classify: (Value, Value) -> NavigationType?

    init(initial: Value, stack: SwiftUIScreenStack, classify: @escaping (Value, Value) -> NavigationType?) {
      previous = initial
      self.stack = stack
      self.classify = classify
    }

    func observe(_ value: Value) {
      if let navigation = classify(previous, value) {
        stack.expect(navigation)
      }
      previous = value
    }
  }

  @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
  struct NavigationChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @State private var observer: NavigationChangeObserver<Value>

    init(value: Value, stack: SwiftUIScreenStack, classify: @escaping (Value, Value) -> NavigationType?) {
      self.value = value
      _observer = State(initialValue: NavigationChangeObserver(initial: value, stack: stack, classify: classify))
    }

    func body(content: Content) -> some View {
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        content.onChange(of: value) { _, newValue in observer.observe(newValue) }
      } else {
        content.onChange(of: value) { newValue in observer.observe(newValue) }
      }
    }
  }

  extension SwiftUIScreenStack {
    /// The kind of navigation that changing a path from `old` to `new` makes, or `nil` when the
    /// top does not change.
    static func navigation<Element: Equatable>(from old: [Element], to new: [Element]) -> NavigationType? {
      guard old != new else { return nil }
      if new.count > old.count, new.starts(with: old) {
        return .push
      }
      if new.count < old.count, old.starts(with: new) {
        return old.count - new.count == 1 ? .pop : .popTo
      }
      if new.count == old.count, old.dropLast() == new.dropLast() {
        return .replace
      }
      return .reset
    }

    /// Modal when a presentation turns on, dismiss when it turns off.
    static func navigation(presenting old: Bool, to new: Bool) -> NavigationType? {
      guard old != new else { return nil }
      return new ? .modal : .dismiss
    }

    /// A switch whenever the selection changes.
    static func navigation<Selection: Equatable>(selecting old: Selection, to new: Selection) -> NavigationType? {
      old == new ? nil : .switch
    }
  }
#endif
