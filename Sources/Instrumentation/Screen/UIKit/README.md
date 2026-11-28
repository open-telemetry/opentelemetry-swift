# UIKit Screens

Status: experimental. Shared names and processors: [Screen README](../README.md).

The **`ScreenInstrumentationUIKit`** module reports every `UIViewController` as a screen. It swizzles `viewDidLoad`, `viewWillAppear(_:)` and `viewDidAppear(_:)` and names each screen after its class. Each appearance sets the current screen. Each instance records one `app.screen.time_to_first_draw` span, from `viewDidLoad` to the first frame displayed after its first `viewWillAppear(_:)`.

The span ends at the first frame, before the transition animation finishes.

![The view controller lifecycle. init and loadView fall outside the span. The span runs from viewDidLoad to the first frame across two stretches: the rest of viewDidLoad and the wait to be shown; appearance callbacks, first layout, render and display. The transition animation and viewDidAppear fall after it.](img/uikit-lifecycle.svg)

Register the [processors](../docs/setup.md), then install on the main thread:

```swift
import ScreenInstrumentationUIKit

ScreenInstrumentationUIKit.install()
```

## Instance properties

### `ScreenUIKitConfig`

<dl>
<dt><code>bundle</code></dt>
<dd>The bundle whose classes are tracked. Defaults to <code>.main</code>, which excludes framework view controllers.</dd>
<dt><code>recordsTimeToFirstDraw</code></dt>
<dd>When set, overrides the tracker's <code>recordsTimeToFirstDraw</code>, so it governs SwiftUI too. Defaults to <code>nil</code>, which keeps the tracker's setting.</dd>
<dt><code>tracksHostingControllers</code></dt>
<dd>Reports <code>UIHostingController</code>s as UIKit screens. Defaults to <code>false</code>; <a href="../SwiftUI/README.md"><code>otelScreen</code></a> names them better.</dd>
</dl>

### `ScreenTrackingCustomization`

Adopt it to rename a view controller or exclude it. It overrides `bundle` and `tracksHostingControllers`.

<dl>
<dt><code>customScreenName</code> <em>Read only</em></dt>
<dd>The name to report. Defaults to <code>nil</code>: the class name, without module prefix or generic arguments.</dd>
<dt><code>tracksScreen</code> <em>Read only</em></dt>
<dd>Whether to report it. Defaults to <code>true</code>. Return <code>false</code> for sensitive or pass-through screens.</dd>
</dl>

```swift
final class LoginViewController: UIViewController, ScreenTrackingCustomization {
  var customScreenName: String? { "Login" }
}

final class DebugViewController: UIViewController, ScreenTrackingCustomization {
  var tracksScreen: Bool { false }
}
```

### `app.screen.time_to_first_draw`

<dl>
<dt>Scope</dt>
<dd><code>io.opentelemetry.screen.uikit</code></dd>
<dt>Start time</dt>
<dd><code>viewDidLoad</code>, when the subclass calls <code>super</code>.</dd>
<dt>End time</dt>
<dd>The first frame displayed after the first <code>viewWillAppear(_:)</code>, read from the display link.</dd>
<dt>Attributes</dt>
<dd><code>app.screen.name</code>; <code>app.screen.type</code> = <code>uikit</code>.</dd>
</dl>

Apple documents this order in [Displaying and managing views with a view controller][seq]. Each row cites Apple's wording.

| Lifecycle step                                    | In span | Time spent on                               | Source                                                                                         |
| ------------------------------------------------- | :-----: | ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `init(nibName:bundle:)`, `init(coder:)`           | —       | Creating the view controller                | [Guide][seq]: "creates that object using its `init(coder:)` method"                            |
| `loadView`                                        | —       | Building or unarchiving the view            | [`loadView()`][loadView]: called "when its view property is requested but is currently nil"    |
| `viewDidLoad`                                     | Start   | Setup after `super`; waiting to be shown    | [`viewDidLoad()`][viewDidLoad]: "after the view controller has loaded its view hierarchy"      |
| `viewWillAppear(_:)`                              | ✓       | Appearance work; the draw read starts       | [`viewWillAppear(_:)`][viewWillAppear]: "before any animations are configured"                 |
| `viewIsAppearing(_:)`                             | ✓       | Updating views with final traits and size   | [`viewIsAppearing(_:)`][viewIsAppearing]: "both callbacks occur within the same CATransaction" |
| `viewWillLayoutSubviews`, `viewDidLayoutSubviews` | ✓       | First layout                                | [Guide][seq]: "Updates the layout of the view hierarchy"                                       |
| First frame                                       | End     | Rendering and displaying the view           | [Guide][seq]: "Displays the views onscreen"                                                    |
| Transition animation                              | —       | Push or presentation animation, if animated | [Guide][seq]: `viewDidAppear(_:)` comes "after any animations complete"                        |
| `viewDidAppear(_:)`                               | —       | Sets the current screen                     | [`viewDidAppear(_:)`][viewDidAppear]: "its view was added to a view hierarchy"                 |

<dl>
<dt>Waiting to be shown</dt>
<dd>A view loads on first access to <a href="https://developer.apple.com/documentation/uikit/uiviewcontroller/view"><code>view</code></a>, not on presentation, so a parent that touches it early starts the span early.</dd>
<dt>First frame</dt>
<dd>Changes made in <code>viewWillAppear(_:)</code> and <code>viewIsAppearing(_:)</code> "become visible to the user at the same time", in one transaction. A <code>CADisplayLink</code> started in <code>viewWillAppear(_:)</code> ignores its first refresh, when that transaction renders, and ends the span at the second, when it is displayed.</dd>
<dt>Background</dt>
<dd>A display link pauses in the background. Entering the background before the first frame cancels the read; the screen's next appearance measures again, from the same load time.</dd>
<dt>Transition animation (future scope)</dt>
<dd>Not measured. A possible UIKit-only <code>app.screen.transition</code> span would run from <code>viewWillAppear(_:)</code> to <code>viewDidAppear(_:)</code>, for animated, non-interactive transitions only. It cannot be a child of <code>time_to_first_draw</code>, which ends where the transition begins. UIKit fixes most of its length, so dropped frames during it would say more than its duration. SwiftUI has no public transition-end callback to match.</dd>
<dt>Navigation event timing</dt>
<dd><code>app.navigation.complete</code> fires at <code>viewDidAppear(_:)</code>, after the transition, so a cancelled interactive pop never changes the screen. SwiftUI fires it at <code>onAppear</code>, before the first frame. The spans align; the event timestamps do not.</dd>
</dl>

[seq]: https://developer.apple.com/documentation/uikit/displaying-and-managing-views-with-a-view-controller#Prepare-your-views-to-appear-onscreen
[loadView]: https://developer.apple.com/documentation/uikit/uiviewcontroller/loadview()
[viewDidLoad]: https://developer.apple.com/documentation/uikit/uiviewcontroller/viewdidload()
[viewWillAppear]: https://developer.apple.com/documentation/uikit/uiviewcontroller/viewwillappear(_:)
[viewIsAppearing]: https://developer.apple.com/documentation/uikit/uiviewcontroller/viewisappearing(_:)
[viewDidAppear]: https://developer.apple.com/documentation/uikit/uiviewcontroller/viewdidappear(_:)

The span excludes work that finishes after the first frame, such as a request that fills the screen. A view controller loaded before `install()` reports the screen change but no span.

## Instance methods

<dl>
<dt><code>ScreenInstrumentationUIKit.install(config:screenTracker:)</code> <em>Static</em></dt>
<dd>Swizzles once per process; later calls return. Registers <code>screenTracker</code> as shared if given. Call on the main thread after registering providers. To avoid swizzling, do not link the module.</dd>
</dl>

## Specifications

| Name                            | Kind      | Specification                                                                               |
| ------------------------------- | --------- | ------------------------------------------------------------------------------------------- |
| `app.screen.type` = `uikit`     | Attribute | [`screen.yaml`](../../SemanticConventions/model/swift/screen.yaml)                          |
| `app.screen.time_to_first_draw` | Span      | [`screen-spans.yaml`](../../SemanticConventions/model/swift/screen-spans.yaml), `uikit` row |
| `app.navigation.complete`       | Event     | [`screen.yaml`](../../SemanticConventions/model/swift/screen.yaml)                          |

## Compatibility

| Platform       | Minimum | Records               | Tested on       |
| -------------- | ------- | --------------------- | --------------- |
| iOS            | 15      | Every view controller | Simulator       |
| iPadOS         | 15      | As iOS                | —               |
| Mac Catalyst   | —       | As iOS                | —               |
| tvOS           | 15      | As iOS                | —               |
| visionOS       | 1       | As iOS                | —               |
| macOS, watchOS | 12, 8   | Nothing               | Unit tests only |
| Linux, Windows | —       | Nothing               | —               |

Untested rows describe the code, not observed telemetry. `install` compiles everywhere. `swift test` on macOS compiles the UIKit paths out; run the [simulator suite](../docs/limits.md#running-the-tests).

## See also

- [Screen Instrumentation](../README.md)
- [SwiftUI screens](../SwiftUI/README.md)
- [Limits and testing](../docs/limits.md): sheets, skipped `super` calls, multiple windows
- [View controller lifecycle](https://developer.apple.com/documentation/uikit/uiviewcontroller#Responding-to-view-related-events)
- [`viewIsAppearing(_:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/viewisappearing(_:))
