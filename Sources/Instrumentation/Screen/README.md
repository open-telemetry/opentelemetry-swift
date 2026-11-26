# Screen Instrumentation

Status: experimental. Span, event and attribute names can change in any release, and this library emits conventions at `development` stability in the [federated registry](../SemanticConventions/model/swift/screen.yaml). Read [Limits and testing](docs/limits.md) before you rely on the names.

The **`ScreenTracker`** class tracks the screen the user is looking at, attaches its name to every span and log record as `app.screen.name`, and reports each change as an `app.navigation.complete` event.

A screen also records one `app.screen.time_to_first_appear` span per instance, measuring creation to first appearance. UIKit screens are detected by swizzling; SwiftUI screens name themselves through a modifier.

Three modules ship separately, so an app links only the front end it uses and a SwiftUI-only app never swizzles `UIViewController`.

<dl>
<dt><code>ScreenInstrumentation</code></dt>
<dd>The tracker and the two processors. Required, and free of UIKit and SwiftUI.</dd>
<dt><code>ScreenInstrumentationUIKit</code></dt>
<dd>Detects UIKit screens by swizzling, and carries <code>install()</code>.</dd>
<dt><code>ScreenInstrumentationSwiftUI</code></dt>
<dd>The <code>otelScreen(_:attributes:)</code> modifier and the <code>ScreenTraceView</code> wrapper. Needs no install step.</dd>
</dl>

The following diagram shows what the span measures and how the current screen moves across a navigation.

![Two parts. Above, a bar for a UIKit screen running from viewDidLoad to viewDidAppear, and a bar for a SwiftUI screen running from state creation to the first onAppear, each one an app.screen.time_to_first_appear span. Below, three boxes showing the current and previous screen as the user pushes from Stories to Comments and then pops back to Stories, with an app.navigation.complete event on each transition, including the pop.](img/screen-timeline.svg)

## Setup

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

## Configuration options

`ScreenUIKitConfig` configures the UIKit module.

<dl>
<dt><code>bundle</code></dt>
<dd>A <code>Bundle</code> whose classes are tracked. Defaults to <code>.main</code>, which keeps <code>UINavigationController</code>, <code>UITabBarController</code> and the frameworks' other plumbing out of the data.</dd>
<dt><code>recordsTimeToFirstAppear</code></dt>
<dd>A Boolean turning on the <code>app.screen.time_to_first_appear</code> span. Defaults to <code>true</code>. Installing applies it to the tracker, so it reaches SwiftUI screens too; a SwiftUI-only app sets <code>ScreenTrackerProvider.getInstance().recordsTimeToFirstAppear</code> instead.</dd>
<dt><code>tracksHostingControllers</code></dt>
<dd>A Boolean reporting SwiftUI hosting controllers as UIKit screens, named after the hosting controller's class. Defaults to <code>false</code>, because a <code>UIHostingController</code> reports a generic wrapper name that buries the SwiftUI screen.</dd>
</dl>

```swift
ScreenInstrumentationUIKit.install(config: ScreenUIKitConfig(
  tracksHostingControllers: true
))
```

There is no switch to turn UIKit detection off: an app that wants no swizzling does not link `ScreenInstrumentationUIKit`.

## UIKit screens

Installing exchanges the implementations of `UIViewController.viewDidLoad` and `UIViewController.viewDidAppear(_:)`. Every view controller in the configured bundle then reports itself, named after its class with the module prefix and any generic arguments removed. Swizzling is process-wide and permanent, so `install()` does it once and later calls return.

`viewDidLoad` records when the screen was created, and `viewDidAppear(_:)` makes it the current screen and ends the span. Note that the current screen follows `viewDidAppear(_:)` rather than `viewDidLoad`, because a view controller loads once: a tracker driven by `viewDidLoad` never learns the user popped back, and every later signal carries the screen they left.

A class adopts `ScreenTrackingCustomization` to rename itself or stay out.

```swift
final class LoginViewController: UIViewController, ScreenTrackingCustomization {
  var customScreenName: String? { "Login" }
}

final class DebugViewController: UIViewController, ScreenTrackingCustomization {
  var tracksScreen: Bool { false }
}
```

## SwiftUI screens

```swift
import ScreenInstrumentationSwiftUI

SettingsView()
  .otelScreen("Settings")
```

The wrapper form suits a view that cannot take a modifier.

```swift
ScreenTraceView("Settings") { SettingsView() }
```

Apply either to a screen rather than to a row or a label, since every appearance sets the current screen. SwiftUI detection is opt-in because a SwiftUI screen has no lifecycle method to swizzle, and finding one means reading SwiftUI's internals; the modifier names the screen instead.

## Emitted telemetry

<dl>
<dt><code>app.navigation.complete</code>, an event</dt>
<dd>One record per screen change, in the shape <a href="https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/events.yaml">opentelemetry-android</a> defines, so one receiver mapping covers both mobile SDKs. It carries <code>app.navigation.destination.name</code>, <code>app.screen.previous.name</code> when there was one, <code>app.screen.name</code> and <code>app.screen.type</code>. Setting the same screen again emits nothing; returning to an earlier screen does, because that is a navigation.</dd>
<dt><code>app.screen.time_to_first_appear</code>, a span</dt>
<dd>One span per screen instance, not per appearance, carrying <code>app.screen.name</code> and <code>app.screen.type</code>. A UIKit screen measures <code>viewDidLoad</code> to its first <code>viewDidAppear(_:)</code>, and a SwiftUI screen measures state creation to its first <code>onAppear</code>. A screen the user returns to records nothing the second time.</dd>
<dt><code>app.screen.name</code>, an attribute</dt>
<dd>The current screen, set on a span when it starts and on a log record when it is emitted, so a span that outlives a navigation keeps the screen that produced it. Neither processor overwrites a value already present, so a crash report replayed from the previous run names the screen that crashed rather than the one visible now.</dd>
</dl>

## Semantic conventions

Every name is generated; none is written by hand. `app.screen.name` comes from the upstream conventions as `SemanticConventions.App.screenName`, and the rest from this repo's federated registry as `FederatedSemanticConventions`, defined in [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml) and [`screen-spans.yaml`](../SemanticConventions/model/swift/screen-spans.yaml).

| Name | Kind | Source |
| --- | --- | --- |
| `app.screen.name` | attribute | Upstream semantic conventions |
| `app.navigation.complete` | event | `opentelemetry-android` |
| `app.navigation.destination.name` | attribute | `opentelemetry-android` |
| `app.screen.previous.name` | attribute | `opentelemetry-android` |
| `app.screen.type` | attribute | This registry; no other SDK defines it |
| `app.screen.time_to_first_appear` | span | This registry; no other SDK defines it |

Upstream deprecated `screen.name` in favour of `app.screen.name`, and Android renamed `last.screen.name` to `app.screen.previous.name`. This module uses the current names. `ScreenConstants` holds only the two instrumentation scopes and the notification name, which are not semantic conventions.

## Platform support

`ScreenInstrumentationUIKit` needs UIKit, so it does nothing on macOS and watchOS. `ScreenInstrumentationSwiftUI` works everywhere SwiftUI does, and `ScreenInstrumentation` needs neither framework. A `swift test` run on macOS compiles the UIKit paths out entirely; see [Limits and testing](docs/limits.md).

## See also

- [Limits and testing](docs/limits.md)
- [App Launch Instrumentation](../AppLaunch/README.md)
- [OpenTelemetry Android screen conventions](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/registry.yaml)
