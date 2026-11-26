# Screen Instrumentation

Status: experimental. Span, event and attribute names can change in any release, and this library emits conventions at `development` stability. Read [Limits and testing](docs/limits.md) before you rely on them.

The **`ScreenTracker`** class provides methods and properties to record which screen a person is looking at and how long each screen took to appear. For example, this class can be used to tell which screen produced a network error, or which screen is slowest to draw.

One tracker serves the whole app, so there is normally one `ScreenTracker` instance, reached through `ScreenTrackerProvider`. Three modules ship separately, and an app links only the front end it uses: `ScreenInstrumentation` holds this class and the two processors and imports neither UIKit nor SwiftUI, `ScreenInstrumentationUIKit` reports UIKit screens by swizzling, and `ScreenInstrumentationSwiftUI` reports SwiftUI screens through a view modifier. A SwiftUI-only app therefore never swizzles `UIViewController`.

The following diagram shows the span each screen records and how the current screen moves across a navigation.

![Two parts. Above, a bar for a UIKit screen running from viewDidLoad to viewDidAppear, and a bar for a SwiftUI screen running from state creation to the first onAppear, each one an app.screen.time_to_first_appear span. Below, three boxes showing the current and previous screen as the user pushes from Stories to Comments and then pops back to Stories, with an app.navigation.complete event on each transition, including the pop.](img/screen-timeline.svg)

## Constructor

<dl>
<dt><code>ScreenTracker(recordsTimeToFirstAppear:)</code></dt>
<dd>Creates a tracker. Apps use the shared instance from <code>ScreenTrackerProvider.getInstance()</code> instead; construct one directly only in tests.</dd>
</dl>

## Instance properties

<dl>
<dt><code>ScreenTracker.currentScreen</code> <em>Read only</em></dt>
<dd>A string naming the screen the user is looking at, or <code>nil</code> before the first screen appears.</dd>
<dt><code>ScreenTracker.previousScreen</code> <em>Read only</em></dt>
<dd>A string naming the screen that was visible before <code>currentScreen</code>, or <code>nil</code> when there was none.</dd>
<dt><code>ScreenTracker.recordsTimeToFirstAppear</code></dt>
<dd>A Boolean controlling whether a screen records an <code>app.screen.time_to_first_appear</code> span. Defaults to <code>true</code>. The tracker holds it rather than either front end, so turning it off reaches UIKit and SwiftUI alike. Set it before the first screen appears.</dd>
</dl>

## Instance methods

<dl>
<dt><code>ScreenTracker.setCurrent(screen:type:timestamp:logger:attributes:)</code></dt>
<dd>Records that a screen is now visible and emits one <code>app.navigation.complete</code> event. Setting the screen that is already current does nothing, so a screen that reappears without an intervening screen produces no second event.</dd>
<dt><code>ScreenTracker.recordTimeToFirstAppear(screen:type:loadTime:appearTime:attributes:)</code></dt>
<dd>Records one <code>app.screen.time_to_first_appear</code> span covering <code>loadTime</code> to <code>appearTime</code>. Returns without recording when <code>recordsTimeToFirstAppear</code> is <code>false</code>.</dd>
</dl>

## Static methods

<dl>
<dt><code>ScreenInstrumentationUIKit.install(config:screenTracker:)</code></dt>
<dd>Swizzles <code>UIViewController.viewDidLoad</code> and <code>viewDidAppear(_:)</code> so every view controller reports itself, named after its class with the module prefix and any generic arguments removed. Swizzling is process-wide and permanent, so the method does its work once and later calls return. Call it on the main thread after registering the providers.

<code>config</code> is a <code>ScreenUIKitConfig</code> with the following properties:

<dl>
<dt><code>bundle</code></dt>
<dd>A <code>Bundle</code> whose classes are tracked. Defaults to <code>.main</code>, which keeps <code>UINavigationController</code>, <code>UITabBarController</code> and the frameworks' other plumbing out of the data.</dd>
<dt><code>recordsTimeToFirstAppear</code></dt>
<dd>A Boolean applied to the tracker at install, so it governs SwiftUI screens too. Defaults to <code>true</code>.</dd>
<dt><code>tracksHostingControllers</code></dt>
<dd>A Boolean reporting SwiftUI hosting controllers as UIKit screens, named after the hosting controller's class. Defaults to <code>false</code>, because a <code>UIHostingController</code> reports a wrapper name that buries the SwiftUI screen.</dd>
</dl>

There is no option to turn UIKit detection off: an app that wants no swizzling does not link the module.</dd>
</dl>

## SwiftUI modifiers

<dl>
<dt><code>View.otelScreen(_:attributes:)</code></dt>
<dd>Reports the view it is applied to as a screen, named by its first argument. Apply it to a screen rather than to a row or a label, since every appearance sets the current screen.</dd>
<dt><code>ScreenTraceView(_:attributes:content:)</code></dt>
<dd>The same behaviour as a wrapper view, for content that cannot take a modifier.</dd>
</dl>

A view controller adopts `ScreenTrackingCustomization` to rename itself or stay out:

```swift
final class LoginViewController: UIViewController, ScreenTrackingCustomization {
  var customScreenName: String? { "Login" }
}

final class DebugViewController: UIViewController, ScreenTrackingCustomization {
  var tracksScreen: Bool { false }
}
```

## Events

<dl>
<dt><code>app.navigation.complete</code></dt>
<dd>Emitted on each screen change, in the shape <a href="https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/events.yaml">opentelemetry-android</a> defines, so one receiver mapping covers both mobile SDKs. It carries <code>app.navigation.destination.name</code>, <code>app.screen.previous.name</code> when there was one, <code>app.screen.name</code> and <code>app.screen.type</code>. Returning to an earlier screen emits one, because that is a navigation.</dd>
</dl>

## Examples

### Reporting every screen in an app

Register the providers first, then install. Installing swizzles `UIViewController`, and the first screen can appear immediately afterwards.

```swift
import ScreenInstrumentation
import ScreenInstrumentationUIKit
import OpenTelemetrySdk

let tracerProvider = TracerProviderBuilder()
  .with(resource: resource)
  .add(spanProcessor: ScreenSpanProcessor())
  .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
  .build()
OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

let loggerProvider = LoggerProviderBuilder()
  .with(resource: resource)
  .with(processors: [
    ScreenLogRecordProcessor(nextProcessor: BatchLogRecordProcessor(logRecordExporter: logExporter))
  ])
  .build()
OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

ScreenInstrumentationUIKit.install()
```

`ScreenSpanProcessor` must run before the exporting processor, and `ScreenLogRecordProcessor` must wrap it, because the attribute is attached before batching.

### Naming a SwiftUI screen

```swift
import ScreenInstrumentationSwiftUI

SettingsView()
  .otelScreen("Settings")
```

### Reading the current screen

```swift
let tracker = ScreenTrackerProvider.getInstance()
print(tracker.currentScreen ?? "nil", tracker.previousScreen ?? "nil")
```

## Specifications

Every name is generated; none is written by hand. `app.screen.name` comes from the upstream conventions as `SemanticConventions.App.screenName`, and the rest from this repository's federated registry as `FederatedSemanticConventions`.

| Name | Kind | Defined in |
| --- | --- | --- |
| `app.screen.name` | attribute | Upstream semantic conventions |
| `app.navigation.complete` | event | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), after `opentelemetry-android` |
| `app.navigation.destination.name` | attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), after `opentelemetry-android` |
| `app.screen.previous.name` | attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), after `opentelemetry-android` |
| `app.screen.type` | attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml); no other SDK defines it |
| `app.screen.time_to_first_appear` | span | [`screen-spans.yaml`](../SemanticConventions/model/swift/screen-spans.yaml); no other SDK defines it |

Upstream deprecated `screen.name` in favour of `app.screen.name`, and Android renamed `last.screen.name` to `app.screen.previous.name`. This module uses the current names. `ScreenConstants` holds only the two instrumentation scopes and the notification name, which are not semantic conventions.

## Platform support

| Module | Platforms |
| --- | --- |
| `ScreenInstrumentation` | Every platform the package supports |
| `ScreenInstrumentationUIKit` | iOS, iPadOS, tvOS and Mac Catalyst; does nothing on macOS and watchOS |
| `ScreenInstrumentationSwiftUI` | Every platform SwiftUI supports |

A `swift test` run on macOS compiles the UIKit paths out entirely, so a green macOS run says nothing about them. See [Limits and testing](docs/limits.md).

## See also

- [`Limits and testing`](docs/limits.md)
- [`App Launch Instrumentation`](../AppLaunch/README.md)
- [`opentelemetry-android` screen conventions](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/registry.yaml)
