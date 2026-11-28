# SwiftUI Screens

Status: experimental. Shared names and processors: [Screen README](../README.md).

The **`ScreenInstrumentationSwiftUI`** module reports SwiftUI views marked as screens. `otelScreen(_:attributes:)` wraps a view in a `ScreenTraceView`. A new screen becomes current when it appears; when a screen is removed, such as by a pop or a dismissed sheet, the screen beneath it becomes current again. Events carry a [navigation type](#navigation-types) when one can be told. Each view identity records one `app.screen.time_to_first_draw` span, from when the view was built to the first frame displayed after its first `onAppear`. It swizzles nothing.

On macOS and watchOS, which have no display link, the span ends at `onAppear` instead.

![The SwiftUI view lifecycle. The span runs from the ScreenTraceView being built to the first frame, covering insertion, body, layout, onAppear and rendering. The transition animation falls outside it.](img/swiftui-lifecycle.svg)

Register the [processors](../docs/setup.md), then mark each screen:

```swift
import ScreenInstrumentationSwiftUI

SettingsView()
  .otelScreen("Settings")
```

## Instance properties

### `app.screen.time_to_first_draw`

<dl>
<dt>Scope</dt>
<dd><code>io.opentelemetry.screen.swiftui</code></dd>
<dt>Start time</dt>
<dd>When the parent's <code>body</code> built the <code>ScreenTraceView</code> that SwiftUI kept.</dd>
<dt>End time</dt>
<dd>The first frame displayed after the first <code>onAppear</code>, read from the display link. On macOS and watchOS, the first <code>onAppear</code>.</dd>
<dt>Attributes</dt>
<dd><code>app.screen.name</code>; <code>app.screen.type</code> = <code>swiftui</code>; the modifier's <code>attributes</code>.</dd>
</dl>

SwiftUI has no public callback between building a view and `onAppear`, so the span cannot be divided there, and those rows follow no documented order.

| Lifecycle step                           | In span | Time spent on                              | Source                                                                                       |
| ---------------------------------------- | :-----: | ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Parent's `body` builds `ScreenTraceView` | Start   | Creating the `@State` that holds the start | [`State`][state]: "always instantiates its default value when SwiftUI instantiates the view" |
| Insertion into the view graph            | ✓       | Waiting to be shown                        | Not documented                                                                               |
| Content `body`                           | ✓       | Evaluating the screen's views              | Not documented                                                                               |
| Layout                                   | ✓       | Sizing and placing views                   | Not documented                                                                               |
| `onAppear`                               | ✓       | Reports a new screen; the draw read starts | [`onAppear(perform:)`][onAppear]: "completes before the first rendered frame appears"        |
| First frame                              | End     | Rendering and displaying the view          | [`onAppear(perform:)`][onAppear]: as above; read from the display link                       |
| Transition animation                     | —       | Push or presentation animation             | Not documented                                                                               |

<dl>
<dt>Early start</dt>
<dd><code>@State</code> creates its default value each time the view value is built, and SwiftUI keeps the state of the value it inserts. <a href="https://developer.apple.com/documentation/swiftui/navigationlink/init(destination:label:)-27n7s"><code>NavigationLink(destination:label:)</code></a> takes a non-escaping <code>destination</code> closure, which must run inside the initializer, so the destination is built on every parent update and the span starts at the last one before the tap. <a href="https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)"><code>navigationDestination(for:destination:)</code></a> builds the destination when the stack presents it.</dd>
<dt>First frame</dt>
<dd>Apple guarantees that <code>onAppear</code> completes before the first rendered frame, though the exact moment "depends on the specific view type". A <code>CADisplayLink</code> started in <code>onAppear</code> ignores its first refresh, when that frame renders, and ends the span at the second, when it is displayed.</dd>
<dt>Background</dt>
<dd>Entering the background before the first frame cancels the read; the view's next appearance measures again, from the same load time.</dd>
</dl>

[state]: https://developer.apple.com/documentation/swiftui/state
[onAppear]: https://developer.apple.com/documentation/swiftui/view/onappear(perform:)

A returning screen sets the current screen but records no span. A recreated view, after an identity change or lazy-container recycling, records a new one.

### Navigation types

SwiftUI reports no navigation, only each view's `onAppear` and `onDisappear`, so this front end reads the stack from two facts measured on iOS 18.5 and 27. A covered view keeps its `@State`; a removed view's state is freed in the same moment as its own `onDisappear`. And that `onDisappear` arrives well after the revealed view's `onAppear`: about half a second on a pop. So a brand-new screen reports a push at once, while a screen that reappears waits for the removal. 0.1 seconds after each `onDisappear`, the number of screens freed tells a pop from a pop to an earlier screen. A main-loop turn is not long enough.

| Value     | Automatic                                                | With an opt-in modifier                                                 |
| --------- | -------------------------------------------------------- | ----------------------------------------------------------------------- |
| `initial` | The first screen of the process, labelled by the tracker | Same                                                                    |
| `push`    | A screen appears that was not on the stack               | `otelNavigationPath(_:)` sees the path grow                             |
| `pop`     | One screen is freed, revealing another                   | The path loses its last element                                         |
| `pop_to`  | Several screens are freed at once                        | The path loses several elements                                         |
| `replace` | Not detected                                             | The path swaps its last element; needs `.id(route)` on each destination |
| `reset`   | Not detected                                             | The path is replaced; needs `.id(route)` on each destination            |
| `modal`   | Reported as `push`                                       | `otelModal(_:)` sees `true`, or `otelModal(item:)` an item              |
| `dismiss` | Reported as `pop`                                        | `otelModal(_:)` sees `false`, or `otelModal(item:)` `nil`               |
| `switch`  | Not detected; the screen changes with no type            | `otelTabSelection(_:)` sees a new selection                             |

```swift
NavigationStack(path: $path) {
  StoriesView()
    .navigationDestination(for: Route.self) { route in
      RouteView(route).id(route)
    }
}
.otelNavigationPath(path)
.sheet(isPresented: $showsSettings) { SettingsView() }
.otelModal(showsSettings)
```

Each modifier watches the value with `onChange`, which sees every change, whether the app or SwiftUI made it, before the destination view appears. It labels the screen change the views report next, within two seconds, and changes nothing about the app's state.

<dl>
<dt>Gaps</dt>
<dd>Without the modifiers: replace, reset, tab switches and split-view selection go undetected, and a replace or reset whose destination keeps its view type fires no callbacks at all, so the current screen goes stale. Pushing several screens in one step reports the wrong top. A SwiftUI screen presented by UIKit, such as a <code>UIHostingController</code> passed to <code>present</code>, reports <code>push</code>, not <code>modal</code>. A list row marked as a screen reports a false screen each time it scrolls into view. A pop is reported about half a second after the revealed screen appears. Unverified: iPad and regular-width split views, <code>NavigationPath</code>, and real devices.</dd>
<dt>Opting out</dt>
<dd><code>ScreenTracker(tracksNavigation: false)</code> reports every appearance as the current screen, ignores disappearances, and drops the type, as before navigation tracking.</dd>
</dl>

## Instance methods

<dl>
<dt><code>View.otelScreen(_:attributes:)</code></dt>
<dd>Reports the view as a screen with the given name and attributes. Use a stable name. Apply it to screens, not rows: any appearance can make the view current.</dd>
<dt><code>ScreenTraceView(_:attributes:content:)</code></dt>
<dd>The same, as a wrapper view.</dd>
<dt><code>View.otelNavigationPath(_:)</code></dt>
<dd>Pass a <code>NavigationStack</code> path that is an array of <code>Equatable</code> routes. Labels push, pop, pop_to, replace and reset by comparing the old path with the new.</dd>
<dt><code>View.otelModal(_:)</code>, <code>View.otelModal(item:)</code></dt>
<dd>Pass the <code>Bool</code> or optional item that shows a sheet or full-screen cover. Labels modal when it is shown and dismiss when it goes away, by the app or a swipe.</dd>
<dt><code>View.otelTabSelection(_:)</code></dt>
<dd>Pass a <code>TabView</code> selection. Labels each change of tab as a switch.</dd>
</dl>

## Specifications

| Name                            | Kind      | Specification                                                                                                 |
| ------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------- |
| `app.screen.type` = `swiftui`   | Attribute | [`screen.yaml`](../../SemanticConventions/model/swift/screen.yaml)                                            |
| `app.screen.time_to_first_draw` | Span      | [`screen-spans.yaml`](../../SemanticConventions/model/swift/screen-spans.yaml), `swiftui` row                 |
| `app.navigation.complete`       | Event     | [`screen.yaml`](../../SemanticConventions/model/swift/screen.yaml)                                            |
| `app.navigation.type`           | Attribute | [`screen.yaml`](../../SemanticConventions/model/swift/screen.yaml); see [Navigation types](#navigation-types) |

## Compatibility

| Platform       | Minimum | Records            | Tested on                    |
| -------------- | ------- | ------------------ | ---------------------------- |
| iOS            | 15      | Every marked view  | Simulator, integration tests |
| iPadOS         | 15      | As iOS             | —                            |
| Mac Catalyst   | —       | As iOS             | —                            |
| tvOS           | 15      | As iOS             | —                            |
| visionOS       | 1       | As iOS             | —                            |
| macOS          | 12      | Ends at `onAppear` | Unit tests only              |
| watchOS        | 8       | Ends at `onAppear` | —                            |
| Linux, Windows | —       | Nothing; no API    | —                            |

Untested rows describe the code, not observed telemetry. On Linux and Windows, guard `otelScreen` calls with `canImport(SwiftUI)`.

## See also

- [Screen Instrumentation](../README.md)
- [UIKit screens](../UIKit/README.md): `tracksHostingControllers` for mixed apps
- [Limits and testing](../docs/limits.md)
- [`onAppear(perform:)`](https://developer.apple.com/documentation/swiftui/view/onappear(perform:))
- [`State`](https://developer.apple.com/documentation/swiftui/state)
