# App Launch Instrumentation

Status: experimental. Span and attribute names can change in any release, and this library emits conventions at `development` stability in the [federated registry](../SemanticConventions/model/swift/registry.yaml). Read [Accuracy and limits](docs/accuracy.md) before you rely on the numbers.

The **`MincoreLaunchInstrumentation`** class records how long the app takes to become usable after a user brings it to the foreground. It reports each launch as an `app.start` span and each resume as an `app.resume` span, in the `io.opentelemetry.lifecycle` scope that [OpenTelemetry Android](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity) also uses.

A process records at most one launch, so there is at most one `app.start` span per process. The start types follow Apple's definitions rather than Android's.

![Timeline of the app.start and app.resume spans. One bar spans process start to the first frame displayed. Below it three phase bars divide the same interval: app.start.pre_init ends at the AppLaunchEnvironment constructor, app.start.app_init ends at didFinishLaunching, and app.start.render ends at the first frame. app.start.scene_setup sits under app.start.render and starts at UIScene.willConnectNotification. A second row shows a prewarmed launch, whose span starts where app code first ran, with app.start.pre_activation.duration recorded outside it. A third row shows a resume, running from willEnterForeground, or from UIScene.willConnectNotification when the system discarded the scene, to the first frame, with an app.resume.scene_setup child and app.resume.background_duration recorded outside it.](img/app-start-timeline.svg)

## Setup

Install the instrumentation before the app first becomes active. Installing is idempotent and thread-safe, and each span uses the tracer provider registered when the app becomes active.

```swift
import MincoreLaunchInstrumentation

MincoreLaunchInstrumentation.install()
```

To change what the library records, pass a configuration.

```swift
MincoreLaunchInstrumentation.install(
  configuration: AppLaunchInstrumentationConfiguration(
    launchTypes: [.cold, .warm, .resume],
    maxLaunchDuration: 60,
    coldPageInRatio: 0.5
  )
)
```

<dl>
<dt><code>launchTypes</code></dt>
<dd>A set of the start types to record. Defaults to <code>[.cold, .warm, .resume, .prewarmed]</code>. The library still tracks an activation of a type you leave out, so that later ones classify correctly, and records no span for it.</dd>
<dt><code>maxLaunchDuration</code></dt>
<dd>A number of seconds giving the longest launch to record, measured from process start, or from when app code first ran for a prewarmed launch. Defaults to <code>60</code>. The library <a href="docs/lifecycle.md#dropped-starts">drops</a> a longer launch.</dd>
<dt><code>coldPageInRatio</code></dt>
<dd>A number above 0 and at most 1 giving the share of sampled code a launch must page in from disk to count as <code>cold</code>. Defaults to <code>0.5</code>. Note that how high the ratio goes depends on the app, so check the ratios yours reports before changing this.</dd>
</dl>

Spans also carry `session.id` and `session.previous_id` once you register the [Sessions](../Sessions/README.md) span processor. To see why the library recorded a start, or why it did not, turn on [debug logging](docs/lifecycle.md#debugging).

## `app.start` and `app.resume`

The [federated registry](../SemanticConventions/model/swift/spans.yaml) defines both spans and every attribute they carry. The schema follows W3C `PerformanceNavigationTiming`: a time origin, `xxxStart` and `xxxEnd` timestamps, a `type` and an `activationStart`. Each phase is a child span, because OpenTelemetry is deprecating span events.

An `app.start` span runs from process start to the first frame displayed after the app first becomes active, read with a `CADisplayLink`. A prewarmed launch starts instead at the first timestamp app code recorded, because its process began before the user launched the app.

| Child span              | Parent             | Runs from                                                            | To                                 |
| ----------------------- | ------------------ | -------------------------------------------------------------------- | ---------------------------------- |
| `app.start.pre_init`    | `app.start`        | Process start                                                        | `AppLaunchEnvironment` constructor |
| `app.start.app_init`    | `app.start`        | `AppLaunchEnvironment` constructor                                   | `didFinishLaunching` end           |
| `app.start.render`      | `app.start`        | `didFinishLaunching` end                                             | End of `app.start`                 |
| `app.start.scene_setup` | `app.start.render` | First scene connecting, or `didFinishLaunching` end if that was later | End of `app.start`                 |

An `app.resume` span runs from `willEnterForeground`, or from `UIScene.willConnectNotification` when the system discarded the app's scene, to the first frame after the app becomes active. See [When a span is emitted](docs/lifecycle.md) for the lifecycle rules and the cases the library records nothing for.

When the app becomes active and then leaves before its first frame, the span ends at that moment and `app.start.outcome` reads `abandoned`. The `app.start.duration` and `app.resume.duration` histograms record completed starts, in seconds.

## Start types

Apple's [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time) calls an activation a _launch_ when the process needs to start, and a _resume_ when the app already had a process alive. A launch is _warm_ when the system still has the app in memory, and _cold_ when it has to _page it in_ from disk.

Apple's wording covers the frameworks and daemons the app depends on, but the sample reaches only the app's own images, so the app's code alone decides the type. See [How the launch type is decided](docs/classification.md).

![Two-part diagram. Part one shows an image's segments — __TEXT, __DATA_CONST, __DATA and __LINKEDIT — with __TEXT highlighted as the only one sampled, because it holds read-only code the kernel discards and re-reads, although a cold launch reads all four from disk, and expands it into a strip of up to 256 evenly spaced sampled pages. Part two shows those pages as cells at two moments, at the library's constructor and when the app became active, for a cold launch and a warm one. In the cold launch 70 pages were already resident and 170 paged in, giving a ratio of 0.71; in the warm launch 233 were already resident and 7 paged in, giving 0.03. A scale at the bottom marks both ratios either side of the 0.5 coldPageInRatio threshold.](img/text-page-sampling.svg)

The `app.start.type` attribute can have the following values, each given with Apple's term for it.

<dl>
<dt><code>cold</code>, Apple's cold launch</dt>
<dd>A new process whose launch read the app's code from disk: its page-in ratio is at least <code>coldPageInRatio</code>.</dd>
<dt><code>warm</code>, Apple's warm launch</dt>
<dd>A new process whose launch found the app's code already in memory: its page-in ratio is below <code>coldPageInRatio</code>.</dd>
<dt><code>prewarmed</code>, Apple's warm launch</dt>
<dd>A new process the system created before the user launched the app. See <a href="docs/classification.md#prewarming">Prewarming</a>.</dd>
</dl>

`resume` is a `launchTypes` option rather than an `app.start.type` value, because a resume becomes an `app.resume` span carrying an `app.resume.type` of its own.

### Resume types

The `app.resume.type` attribute can have the following values. Each describes a process that was already alive, so none of them is a launch.

<dl>
<dt><code>hot</code></dt>
<dd>A return to the foreground with the app's UI still built. This is the ordinary case, and it covers a launch the user left before its first frame, since that launch reached the background with its UI built.</dd>
<dt><code>scene_reconnect</code></dt>
<dd>A return to the foreground after the system discarded the app's scene, so UIKit connects a new one.</dd>
<dt><code>background_launched</code></dt>
<dd>The first time the app reaches the foreground after the system started the process in the background. Note that such a resume has no page baseline, so it reports none of the <code>app.resume.pages.text.*</code> attributes.</dd>
</dl>

## Platform support

| Platform       | Status      | Tested on            | What the library records                                           |
| -------------- | ----------- | -------------------- | ------------------------------------------------------------------ |
| iOS            | Development | Device and simulator | Every type                                                         |
| iPadOS         | Untested    | Neither              | The same as iOS                                                    |
| visionOS       | Untested    | Neither              | Every type, with `prewarmed` only where the system sets `ActivePrewarm` |
| Mac Catalyst   | Untested    | Neither              | The same as visionOS                                               |
| tvOS           | Untested    | Neither              | The same, except that it reads no background launch from the process's role |
| macOS          | Untested    | Neither, and it has no simulator | Launches only, ending at the first `NSApplication.didBecomeActiveNotification`, because macOS has neither `CADisplayLink` nor a background state |
| watchOS        | Unsupported | —                    | Nothing. The API compiles, so shared code needs no check           |
| Linux, Windows | Unsupported | —                    | Nothing. The product is not built, so it cannot be a dependency    |

`Untested` means nobody has collected telemetry from that platform, so the row describes what the code would record. A simulator reads the Mac's page cache, so it exercises the lifecycle but says nothing about `cold` and `warm`, and it cannot produce a `prewarmed` launch: only the device run supports the thresholds. See [What has been verified](docs/accuracy.md#what-has-been-verified).

## See also

- [How the launch type is decided](docs/classification.md): page sampling, the launch history fallback, prewarming, and how the types differ from Android's
- [When a span is emitted](docs/lifecycle.md): resume rules, dropped starts, and debug logging
- [Accuracy and limits](docs/accuracy.md): the comparison with Instruments, what has been verified, known limits, and what is not recorded yet
- [Navigation Timing Level 2](https://www.w3.org/TR/navigation-timing-2/): the W3C `PerformanceNavigationTiming` model this schema follows, for the time origin, the `xxxStart` and `xxxEnd` pairs, `type` and `activationStart`
- [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time): Apple's definitions of activation, launch, resume, and cold and warm launches
- [`CADisplayLink`](https://developer.apple.com/documentation/quartzcore/cadisplaylink): how the library reads the first frame, and so where every launch and resume span ends
- [MXAppLaunchMetric](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric): the system's own launch and resume histograms, through the [MetricKit](../MetricKit/README.md) instrumentation
- [OpenTelemetry Android activity instrumentation](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity)
