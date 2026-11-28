# Screen Instrumentation

Status: experimental. Names may change in any release. Conventions are at `development` stability in the [federated registry](../SemanticConventions/model/swift/screen.yaml). See [Limits and testing](docs/limits.md).

The **`ScreenTracker`** class answers two questions about the screens a user sees: where the user went, and how long each screen took to draw. An event answers the first and a span the second. The tracker also stamps `app.screen.name` on every other span and log record.

This module imports neither UIKit nor SwiftUI. A front end feeds it; link only the one you use:

- [**UIKit**](UIKit/README.md): reports every view controller by swizzling.
- [**SwiftUI**](SwiftUI/README.md): reports views marked with a modifier. Swizzles nothing.

Each front end documents its own lifecycle. iOS is the primary platform.

A user's journey, as events and spans:

![A user journey across two sessions. On screen: Stories, Comments, Stories in session a2b7, then Settings in session 9f1c after a timeout. Events: four app.navigation.complete records numbered 1, 2, 3, then 1 again in the new session, each naming the destination and the previous screen. Spans: time_to_first_draw for Stories, Comments and Settings, and none for the pop back.](img/screen-navigation.svg)

One push, close up: where the event and the span end for each front end.

![Two rows for one push. UIKit: the span runs from viewDidLoad through viewWillAppear to the first frame; the push transition follows, and the event fires at viewDidAppear. SwiftUI: the span runs from ScreenTraceView built to the first frame, and the event fires at onAppear, inside the span.](img/screen-push-timing.svg)

## Concepts

### Navigation

A navigation is a change of the current screen. Each one emits an [`app.navigation.complete`](#appnavigationcomplete) event naming the screen reached and the screen left. In order, the events trace the user's path; the gaps between them give the time spent on each screen. A pop back counts like any other move. Setting the current screen to itself emits nothing, so a redisplay is not a navigation.

The front ends follow the navigation stack, so the current screen is the one on top. A dismissed sheet makes the screen beneath it current again, even though neither UIKit nor SwiftUI tells the presenter it reappeared. When a front end can tell how the user got there, the event says so in `app.navigation.type`. Navigation tracking is on by default; `ScreenTracker(tracksNavigation: false)` turns it off.

Each event carries `app.navigation.sequence`, its position within the session: 1, 2, 3 and so on. A gap in the numbers within one `session.id` means events were lost. The count persists with the session's identifier, so it continues after a restart that resumes the session, and starts again at 1 in a new one.

### Navigation types

`app.navigation.type` takes one of these values, and is absent when the front end cannot tell. They extend the W3C Navigation API's `push`, `replace` and `traverse`, which cannot tell a back step from a jump, a sheet from a push, or a tab change from either.

| Value     | What happened                                                            | Stack              |
| --------- | ------------------------------------------------------------------------ | ------------------ |
| `initial` | The first screen of the process appeared                                 | `[] → [a]`         |
| `push`    | A new screen went on top                                                 | `[a] → [a, b]`     |
| `pop`     | The top screen left, revealing the one beneath                           | `[a, b] → [a]`     |
| `pop_to`  | Several screens left at once, revealing an earlier one                   | `[a, b, c] → [a]`  |
| `replace` | The top screen was swapped; the rest stayed                              | `[a, b] → [a, c]`  |
| `reset`   | Every screen was replaced                                                | `[a, b] → [x]`     |
| `modal`   | A sheet or full-screen cover was shown                                   | `[a] → [a, sheet]` |
| `dismiss` | A sheet or cover was dismissed, revealing its presenter                  | `[a, sheet] → [a]` |
| `switch`  | An existing screen became current and nothing left, such as a tab change | `[a, b] → [b, a]`  |

Each front end detects a different set. ✓ means detected; a blank means the event carries no type.

| Value     | UIKit | SwiftUI            | SwiftUI with opt-in modifiers | `setCurrent` |
| --------- | :---: | :----------------: | :---------------------------: | :----------: |
| `initial` | ✓     | ✓                  | ✓                             | ✓            |
| `push`    | ✓     | ✓                  | ✓                             | if passed    |
| `pop`     | ✓     | ✓                  | ✓                             | if passed    |
| `pop_to`  | ✓     | ✓                  | ✓                             | if passed    |
| `replace` | ✓     |                    | ✓, with `.id(route)`          | if passed    |
| `reset`   | ✓     |                    | ✓, with `.id(route)`          | if passed    |
| `modal`   | ✓     | reported as `push` | ✓                             | if passed    |
| `dismiss` | ✓     | reported as `pop`  | ✓                             | if passed    |
| `switch`  | ✓     |                    | ✓                             | if passed    |

See [UIKit](UIKit/README.md#navigation-types) and [SwiftUI](SwiftUI/README.md#navigation-types) for how each detects them and what each misses.

### Time to first draw

Time to first draw measures how long one screen instance took to arrive: from loading to the first frame that shows it. Each instance records one [`app.screen.time_to_first_draw`](#appscreentime_to_first_draw) span. A screen the user returns to is already drawn, so it records nothing.

### How the two differ

The first diagram above shows the difference over a journey: four navigations, three spans.

|                                    | `app.navigation.complete`  | `app.screen.time_to_first_draw` |
| ---------------------------------- | -------------------------- | ------------------------------- |
| Signal                             | Log record                 | Span                            |
| Answers                            | Where did the user go?     | How fast did the screen arrive? |
| Recorded when                      | The current screen changes | A screen instance first draws   |
| First appearance of a screen       | ✓                          | ✓                               |
| Pop back to a screen               | ✓                          | —                               |
| New instance of the current screen | ✓, when the type is known  | ✓                               |
| `setCurrent` without a front end   | ✓                          | —                               |
| `recordsTimeToFirstDraw = false`   | ✓                          | —                               |
| Duration                           | —                          | ✓                               |
| Previous screen                    | ✓                          | —                               |
| Position in the session            | ✓                          | —                               |
| Trace sampling                     | Does not apply             | Applies                         |

The timestamps differ too, as the second diagram above shows. Even on a first appearance, the event and the end of the span fall at different moments, in a different order for each front end:

- **UIKit** ends the span at the first frame after `viewWillAppear(_:)`, then emits the event at `viewDidAppear(_:)`, after the push transition.
- **SwiftUI** emits the event at `onAppear`, then ends the span at the next frame. On macOS and watchOS, which have no display link, both fall at `onAppear`.

Read arrival time from the event and drawing time from the span. Neither timestamp stands in for the other.

## Usage

`ScreenTrackerProvider` holds the one tracker the processors and front ends share. Register a tracker before anything reads it, or let the first caller create a default one.

```swift
import ScreenInstrumentation

// 1. Optional: share a configured tracker.
ScreenTrackerProvider.register(screenTracker: ScreenTracker(recordsTimeToFirstDraw: true))

// 2. Stamp app.screen.name on every span and log record.
let tracerProvider = TracerProviderBuilder()
  .add(spanProcessor: ScreenSpanProcessor())
  .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
  .build()
let loggerProvider = LoggerProviderBuilder()
  .with(processors: [
    ScreenLogRecordProcessor(nextProcessor: BatchLogRecordProcessor(logRecordExporter: logExporter))
  ])
  .build()
OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

// 3. Install a front end, or report screens yourself.
let tracker = ScreenTrackerProvider.getInstance()
tracker.setCurrent(screen: "Checkout") // a manual screen
print(tracker.currentScreen ?? "nil") // "Checkout"
```

Put `ScreenSpanProcessor` before the exporter, and wrap the exporter in `ScreenLogRecordProcessor`, so the attribute is set before batching. Both processors read the shared tracker at each span or log record unless given one, so a tracker registered later still reaches them. See [Setup](docs/setup.md).

## Instance properties

### `ScreenTracker`

<dl>
<dt><code>currentScreen</code> <em>Read only</em></dt>
<dd>The screen the user sees, or <code>nil</code> before the first appears.</dd>
<dt><code>currentScreenType</code> <em>Read only</em></dt>
<dd>What reported <code>currentScreen</code>: <code>.uikit</code>, <code>.swiftui</code> or <code>.manual</code>, or <code>nil</code> before the first screen appears.</dd>
<dt><code>previousScreen</code> <em>Read only</em></dt>
<dd>The screen before <code>currentScreen</code>, or <code>nil</code>.</dd>
<dt><code>recordsTimeToFirstDraw</code></dt>
<dd>Whether screens record <code>app.screen.time_to_first_draw</code>. Defaults to <code>true</code>. Applies to both front ends. Set it before the first screen appears.</dd>
<dt><code>tracksNavigation</code></dt>
<dd>Whether the front ends follow the navigation stack and report <code>app.navigation.type</code>. Defaults to <code>true</code>. Turned off, the current screen is the last one to appear, a dismissed sheet leaves its name behind, and no event carries a type. The UIKit front end reads it at install, so set it before installing.</dd>
</dl>

## Instance methods

<dl>
<dt><code>setCurrent(screen:type:navigation:timestamp:logger:attributes:)</code></dt>
<dd>Sets the current screen, emits <code>app.navigation.complete</code>, and posts <code>ScreenChangeNotification</code>. Does nothing if the screen is already current and no <code>navigation</code> is given; with one, the event is emitted anyway, because a push of a second instance of the same screen is still a navigation. Pass <code>navigation</code> when the app knows how the user got there. Call it for screens no front end reports, such as a game's scenes or a custom container. <code>type</code> defaults to <code>.manual</code>, so <code>setCurrent(screen: "Checkout")</code> reports a <code>manual</code> screen under the <code>io.opentelemetry.screen</code> scope; the front ends pass <code>.uikit</code> or <code>.swiftui</code>. A manual screen counts in <code>app.navigation.sequence</code> like any other.</dd>
<dt><code>recordTimeToFirstDraw(screen:type:loadTime:drawTime:attributes:)</code></dt>
<dd>Records one span from <code>loadTime</code> to <code>drawTime</code>, unless <code>recordsTimeToFirstDraw</code> is <code>false</code>. Call it once per screen instance.</dd>
</dl>

## Events

### `app.navigation.complete`

One log record per navigation, shaped as in [OpenTelemetry Android](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/events.yaml). A pop back emits one. Setting the current screen to itself emits none, unless the navigation type is known.

#### Event properties

<dl>
<dt>Event name</dt>
<dd><code>app.navigation.complete</code>.</dd>
<dt>Instrumentation scope</dt>
<dd><code>io.opentelemetry.screen.uikit</code> for a UIKit screen, <code>io.opentelemetry.screen.swiftui</code> for a SwiftUI one, <code>io.opentelemetry.screen</code> for a manual one. A <code>logger</code> passed to <code>setCurrent</code> overrides it.</dd>
<dt>Timestamp</dt>
<dd>When the screen became current. UIKit: <code>viewDidAppear(_:)</code>, or the dismissed screen's <code>viewDidDisappear(_:)</code> for a dismissal. SwiftUI: <code>onAppear</code> for a new screen, or the removed screen's <code>onDisappear</code> for a pop. Manual: the <code>timestamp</code> passed to <code>setCurrent</code>.</dd>
</dl>

#### Attributes

<dl>
<dt><code>app.navigation.destination.name</code> <em>Required</em></dt>
<dd>The screen reached. Equals <code>app.screen.name</code>, so apps without <code>ScreenLogRecordProcessor</code> still get it.</dd>
<dt><code>app.screen.previous.name</code> <em>Conditionally required</em></dt>
<dd>The screen left. Absent on the first navigation, which has no screen before it.</dd>
<dt><code>app.screen.type</code> <em>Required</em></dt>
<dd><code>uikit</code>, <code>swiftui</code>, or <code>manual</code> for a screen the app reported through <code>setCurrent</code>.</dd>
<dt><code>app.navigation.type</code> <em>Conditionally required</em></dt>
<dd>How the user got there, from the <a href="#navigation-types">navigation types</a>. <code>initial</code> on the first navigation of the process, whatever reported it. Absent when the front end cannot tell, and on every event when <code>tracksNavigation</code> is off.</dd>
<dt><code>app.navigation.sequence</code> <em>Required</em></dt>
<dd>The navigation's position within the session, starting at 1. Read from the tracker's <code>SessionManager</code>, the shared one unless given another; give <code>SessionLogRecordProcessor</code> the same one so <code>session.id</code> matches. Persisted in <code>UserDefaults</code> under one key, which a new session overwrites.</dd>
<dt><code>app.screen.name</code> <em>Optional</em></dt>
<dd>Stamped by <code>ScreenLogRecordProcessor</code> when installed. Equals the destination.</dd>
<dt>Custom attributes <em>Optional</em></dt>
<dd>From <code>otelScreen(_:attributes:)</code> or the <code>attributes</code> passed to <code>setCurrent</code>. UIKit adds none.</dd>
</dl>

## Spans

### `app.screen.time_to_first_draw`

One span per screen instance, with no children. A returning screen records nothing; so does a screen that never appears. If the app enters the background before the first frame, the read is cancelled and the screen's next appearance measures again, from the same load time.

#### Span properties

<dl>
<dt>Name</dt>
<dd><code>app.screen.time_to_first_draw</code>.</dd>
<dt>Kind</dt>
<dd><code>INTERNAL</code>.</dd>
<dt>Instrumentation scope</dt>
<dd><code>io.opentelemetry.screen.uikit</code> for a UIKit screen, <code>io.opentelemetry.screen.swiftui</code> for a SwiftUI one, <code>io.opentelemetry.screen</code> for one the app records itself with <code>recordTimeToFirstDraw</code>.</dd>
<dt>Start time</dt>
<dd>UIKit: <code>viewDidLoad</code>. SwiftUI: when the parent's <code>body</code> builds the <code>ScreenTraceView</code> value.</dd>
<dt>End time</dt>
<dd>The first frame displayed after the first <code>viewWillAppear(_:)</code> (UIKit) or the first <code>onAppear</code> (SwiftUI). On macOS and watchOS, SwiftUI ends at <code>onAppear</code>. Neither includes the transition animation.</dd>
</dl>

#### Attributes

<dl>
<dt><code>app.screen.name</code> <em>Required</em></dt>
<dd>UIKit: the class name, or <code>customScreenName</code>. SwiftUI: the <code>otelScreen</code> name.</dd>
<dt><code>app.screen.type</code> <em>Required</em></dt>
<dd><code>uikit</code>, <code>swiftui</code>, or <code>manual</code>.</dd>
<dt>Custom attributes <em>Optional</em></dt>
<dd>From <code>otelScreen(_:attributes:)</code> or the <code>attributes</code> passed to <code>recordTimeToFirstDraw</code>. UIKit adds none.</dd>
</dl>

Both front ends end the span at the first frame displayed, read from the display link, so UIKit and SwiftUI durations compare. The first frame is the second display-link refresh after the read starts: a frame committed before one refresh is displayed at the next. [App Launch](../AppLaunch/README.md) reads `app.start`'s end the same way, with the same code. See [UIKit](UIKit/README.md#appscreentime_to_first_draw) and [SwiftUI](SwiftUI/README.md#appscreentime_to_first_draw) for the lifecycle inside each.

## Specifications

All names are generated: `app.screen.name` as `SemanticConventions.App.screenName`, the rest as `FederatedSemanticConventions`.

| Name                              | Kind      | Specification                                                                                                                        |
| --------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `app.screen.name`                 | Attribute | [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/registry/attributes/app/)                           |
| `app.navigation.complete`         | Event     | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), from OpenTelemetry Android                                          |
| `app.navigation.destination.name` | Attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), from OpenTelemetry Android                                          |
| `app.screen.previous.name`        | Attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), from OpenTelemetry Android                                          |
| `app.navigation.sequence`         | Attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), Swift only                                                          |
| `app.navigation.type`             | Attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), Swift only; values extend the W3C Navigation API's `navigationType` |
| `app.screen.type`                 | Attribute | [`screen.yaml`](../SemanticConventions/model/swift/screen.yaml), Swift only                                                          |
| `app.screen.time_to_first_draw`   | Span      | [`screen-spans.yaml`](../SemanticConventions/model/swift/screen-spans.yaml), Swift only                                              |

The module uses the current names, not the deprecated `screen.name` and `last.screen.name`.

## Compatibility

| Module                         | Builds on      | Reports screens on                                                         |
| ------------------------------ | -------------- | -------------------------------------------------------------------------- |
| `ScreenInstrumentation`        | Every platform | Wherever the app calls `setCurrent`                                        |
| `ScreenInstrumentationUIKit`   | Every platform | [iOS, iPadOS, Mac Catalyst, tvOS, visionOS](UIKit/README.md#compatibility) |
| `ScreenInstrumentationSwiftUI` | Every platform | [Every SwiftUI platform](SwiftUI/README.md#compatibility)                  |

Minimums: iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1.

## See also

- [UIKit screens](UIKit/README.md)
- [SwiftUI screens](SwiftUI/README.md)
- [Setup](docs/setup.md)
- [Limits and testing](docs/limits.md)
- [App Launch Instrumentation](../AppLaunch/README.md): the first screen's span overlaps `app.start`
- [Sessions](../Sessions/README.md): the other processors that stamp every span and log record
- [OpenTelemetry Android screen conventions](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/registry.yaml)
- [`NavigateEvent.navigationType`](https://developer.mozilla.org/docs/Web/API/NavigateEvent/navigationType): the W3C values `app.navigation.type` extends
- [`PerformanceNavigationTiming`](https://developer.mozilla.org/en-US/docs/Web/API/PerformanceNavigationTiming): the model for this page's layout
