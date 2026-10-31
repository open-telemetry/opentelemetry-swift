# App Launch Instrumentation

Status: development

Measures how long it takes the app to become usable after a user brings it to the foreground, and reports each activation as an `AppStart` span.

The span name, the `start.type` key, its `cold` and `warm` values and the instrumentation scope are the same as in the [OpenTelemetry Android](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity) activity instrumentation. What each `start.type` value means follows Apple's definitions instead of Android's, and a resume is `resume`, Apple's term, instead of Android's `hot`. See [Start types](#start-types).

## Implementation status

Every span ends at the first frame displayed after the app becomes active, read with a `CADisplayLink`.

## Platform support

| Platform       | Status      | What's recorded                                                                                                                                                                           |
| -------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iOS, iPadOS    | Supported   | `cold`, `warm`, `resume` and `start.active_prewarmed`. Tested with real telemetry on the iOS simulator, except prewarming, which the simulator can't produce.                             |
| visionOS       | Supported   | `cold`, `warm` and `resume`, and `start.active_prewarmed` if the system sets `ActivePrewarm`. Not tested with real telemetry.                                                             |
| Mac Catalyst   | Supported   | `cold`, `warm` and `resume`, and `start.active_prewarmed` if the system sets `ActivePrewarm`. Not tested with real telemetry.                                                             |
| tvOS           | Supported   | `cold`, `warm` and `resume`, and `start.active_prewarmed` if the system sets `ActivePrewarm`. A background launch isn't detected from the process's role. Not tested with real telemetry. |
| macOS          | Partial     | Only `cold` and `warm`, ending at the first `NSApplication.didBecomeActiveNotification`, because macOS has neither `CADisplayLink` nor a background state.                                |
| watchOS        | Unsupported | Nothing. The API compiles, so shared code doesn't need a check, but `install` does nothing, `isInstalled` is always `false`, and no code runs at process start.                           |
| Linux, Windows | Unavailable | The product isn't built, so it can't be added as a dependency.                                                                                                                            |

When the system started the process in the background, the first time the app reaches the foreground is a [`resume`](#resume). Other launches the user can't have waited through are dropped by the [dropped-start rules](#dropped-starts).

## Debugging

Only errors are logged by default. To see why a start was or wasn't recorded, turn on debug mode, which logs every level through `OpenTelemetry.instance.feedbackHandler`:

```swift
OpenTelemetry.setDebugEnabled(true)
```

## Setup

Install the instrumentation as early as possible, before the app first becomes active. Installing is idempotent and thread-safe, and each span is recorded with the tracer provider that is registered when the app becomes active:

```swift
import AppLaunchInstrumentation

AppLaunchInstrumentation.install()
```

To change what's recorded, pass a configuration:

```swift
AppLaunchInstrumentation.install(
  configuration: AppLaunchInstrumentationConfiguration(
    launchTypes: [.cold, .warm],
    dropPrewarmed: false,
    maxLaunchDuration: 60
  )
)
```

| Option              | Default                   | Description                                                                                                                                                                                                                                                                                                                         |
| ------------------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `launchTypes`       | `[.cold, .warm, .resume]` | The [start types](#start-types) to record. Activations of other types don't produce spans, but are still tracked so that later ones are classified correctly.                                                                                                                                                                       |
| `dropPrewarmed`     | `false`                   | Whether to drop [prewarmed](#prewarming) launches instead of recording them. Prewarmed launches are timed from when app code first ran, so they leave out the work the system did ahead of time. As in Sentry (`enablePreWarmedAppStartTracing`) and Datadog, they're recorded by default and marked with `start.active_prewarmed`. |
| `maxLaunchDuration` | `60`                      | The longest launch, in seconds, that's recorded. Longer launches are [dropped](#dropped-starts). It's measured from process start, or from when app code first ran for a prewarmed launch. The default matches Datadog.                                                                                                             |

## Telemetry

### Application Start

- Type: Span
- Name: `AppStart`
- Instrumentation scope: `io.opentelemetry.lifecycle`
- Span kind: `INTERNAL`
- Attributes:

| Attribute                | Type    | Requirement                              | Description                                                                                   | Values                       |
| ------------------------ | ------- | ---------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------- |
| `start.type`             | string  | Required                                 | The kind of activation, as Apple defines it. See [Start types](#start-types).                 | `cold` \| `warm` \| `resume` |
| `start.active_prewarmed` | boolean | Conditionally required: `cold` or `warm` | Whether iOS prewarmed the process before the user launched it. See [Prewarming](#prewarming). | `true` \| `false`            |

The `start.type` key and its `cold` and `warm` values are the same as the `start.type` attribute in the OpenTelemetry Android [semantic convention registry](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/registry.yaml), but their meanings follow Apple's definitions, so they don't describe the same states as on Android. A resume is `resume` instead of Android's `hot`. `start.active_prewarmed` is an iOS-only addition, named after the `ActivePrewarm` environment variable it's read from, because Android has no equivalent of prewarming. The span and both attributes, including each start type's start and end timestamps, are defined in the [federated semantic conventions](../SemanticConventions/README.md) registry, because upstream OpenTelemetry semantic conventions don't define app start conventions yet.

Spans also get `session.id` and `session.previous_id` when the [Sessions](../Sessions/README.md) span processor is registered.

**Example `AppStart` span**:

```json
{
  "name": "AppStart",
  "kind": "INTERNAL",
  "instrumentationScope": { "name": "io.opentelemetry.lifecycle" },
  "startTimeUnixNano": 1761148800000000000,
  "endTimeUnixNano": 1761148800642000000,
  "attributes": {
    "start.type": "cold",
    "start.active_prewarmed": false
  }
}
```

## Start types

Apple's [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time) defines an _activation_ as the user clicking the app's icon or otherwise going back to the app. An activation is either a _launch_, when the process needs to start, or a _resume_, when the app already had a process alive, even if suspended. Apple calls a launch _warm_ when the system still has the app and its dependencies in memory, and _cold_ when it has to page them in from disk, for example in a launch immediately after boot. This schema uses Apple's term, `resume`, where Android uses `hot`.

| `start.type` | Apple term  | Meaning                                                                                      | Android's equivalent value and its meaning                                                      |
| ------------ | ----------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `cold`       | Cold launch | A new process, and the system is unlikely to have the app's code and data cached.            | `cold`: "The application started from scratch, with no process or activity reused."             |
| `warm`       | Warm launch | A new process, and the system is likely to still have the app's code and data cached.        | `warm`: "The application process was reused but the activity had to be recreated."              |
| `resume`     | Resume      | The app's process was still alive, even if suspended, and the app returns to the foreground. | `hot`: "The application and its activity were already in memory and brought to the foreground." |

Apple describes cold and warm launches as a spectrum, because how much the system still has cached depends on what else ran on the device. Code inside the process can't observe the cache, so `cold` and `warm` are inferred from the causes Apple names. A resume after Android's `warm` case, where the system discarded the app's UI but kept its process, is `resume` here, because the process was still alive.

### `cold` and `warm`

Emitted once per process, for the first time the app reaches the foreground, unless the system started the process in the background.

A launch is `cold` when any of these is true, and `warm` otherwise:

- No previous launch is recorded, for example on the app's first launch after it's installed.
- The device booted after the previous launch, detected from a change in the kernel's boot session ID (`sysctl` `kern.bootsessionuuid`). If either launch's boot session ID couldn't be read, a change in the kernel boot time (`sysctl` `KERN_BOOTTIME`) of more than 1 second is used instead; setting the system clock also moves the boot time, so in that case it's treated like a reboot.
- The app's version (`CFBundleShortVersionString`) or build (`CFBundleVersion`) changed since the previous launch, so its new code isn't cached.
- The app was reinstalled since the previous launch, detected from a change in its bundle path, because the system puts every install in a new directory. The same build installed again is `cold` too, since its files were just rewritten.
- The boot time can't be read.

The previous launch's boot session ID, boot time, version, build and bundle path are stored in `UserDefaults.standard` under `io.opentelemetry.lifecycle.lastLaunchContext` when the instrumentation is installed. A launch is recorded even if it never reaches the foreground, because the system still loaded the app's code. So after a reboot or an update, if the system first starts the app in the background, that process produces no `cold` span and the user's next launch is `warm`.

Apple also calls a launch cold when the system evicted the app from memory to make room for other apps. Code inside the process can't tell, so such a launch is reported as `warm` if none of the rules above applies.

|       | Timestamp                                                                                                                                                                                                                 |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start | Process start time, read from the kernel (`sysctl` `KERN_PROC_PID`, `kp_proc.p_starttime`). For a prewarmed launch, the time this module's C initializer ran instead. See [Prewarming](#prewarming).                      |
| End   | The first frame displayed after the app first becomes active, read with a `CADisplayLink` started on `UIApplication.didBecomeActiveNotification`. This matches Apple's launch-time metric, which runs to the first frame. |

### `resume`

Emitted when the app returns to the foreground from the background while its process is still alive. That includes the first time the app reaches the foreground after the system started it in the background, for example for a background fetch or a silent push. A background launch is detected in either of two ways:

- Like Datadog, from the role the system gave the process when it started it (`task_policy_get` with `TASK_CATEGORY_POLICY`), read before `main()`: `TASK_BACKGROUND_APPLICATION`, `TASK_DARWINBG_APPLICATION` or `TASK_NONUI_APPLICATION`, on a process that wasn't [prewarmed](#prewarming). This is only available on iOS, iPadOS, visionOS and Mac Catalyst. It's what detects a background launch in a scene-based app, where UIKit doesn't post `didEnterBackgroundNotification` for it.
- From `UIApplication.didEnterBackgroundNotification` arriving before the app first becomes active, which Apple's [About the background execution sequence](https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence) describes for an app without scenes. This also covers a user leaving the app before its launch finished.

If the role says background but the app becomes active without first entering the foreground, the role was wrong, and the activation is recorded as a launch.

|       | Timestamp                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start | `UIApplication.willEnterForegroundNotification`. If the system discarded the app's scene while the app was in the background, the new scene connects before the app enters the foreground, so the span starts at `UIScene.willConnectNotification` instead. This only applies when the app starts entering the foreground while UIKit handles the same event: a scene the system connects in the background, for example during a background launch, doesn't start a resume. |
| End   | The first frame displayed after the next `UIApplication.didBecomeActiveNotification`                                                                                                                                                                                                                                                                                                                                                                                         |

The `UIApplication` notifications describe the app as a whole, so they work the same with and without scenes.

Not emitted when:

- The app becomes active without first entering the background, for example after the user dismisses Control Center, Notification Center, a system alert or an incoming call. In those cases the app only lost input focus; it never left the foreground.
- A scene connects while the app is already in the foreground, for example when the user opens a second window on iPad.
- The app returns to the background before it becomes active. The activation is abandoned.

## Prewarming

On iOS 15 and later the system can prewarm an app: it creates the process ahead of time and suspends it before any app code runs, then resumes it when the user launches the app. The process start time of a prewarmed launch can be minutes or hours before the user tapped the icon, so it can't be used as the span start.

A launch (`cold` or `warm`) is reported as prewarmed when the `ActivePrewarm` environment variable was `1` when the process started. Apple doesn't document this variable, but Apple engineers have confirmed on the Developer Forums that the system sets it and that `UIApplication` clears it during launch. The module reads it from a C `constructor` function in the `AppLaunchEnvironment` target, which runs before `main()`.
Like Sentry and Datadog, this is the only signal used. A prewarmed launch without `ActivePrewarm` starts at process start, so it's usually longer than `maxLaunchDuration` and dropped.

Prewarming is independent of caching: a prewarmed launch can be `cold` or `warm`. For a prewarmed launch:

- `start.active_prewarmed` is `true`.
- The span starts at the time the `AppLaunchEnvironment` constructor ran, the earliest timestamp recorded by app code, instead of at process start.

The constructor time is a good start time because Apple's [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence) says prewarming "creates your process and loads the libraries your app links against, then suspends your process without allowing any application code to run". Earlier versions of that page said prewarming runs the launch sequence up to `UIApplicationMain`, which would include the constructor. If a system does that, the span is usually longer than `maxLaunchDuration` and is dropped.

## Dropped starts

No `AppStart` span is emitted in these cases:

| Case                                             | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Android equivalent                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| Launch longer than the maximum                   | A launch is longer than `maxLaunchDuration` (60 seconds by default), measured from process start, or from when app code first ran for a prewarmed launch (see [Prewarming](#prewarming)), so the user can't have waited through all of it. This covers a launch the system started in the background whose role couldn't be read, for example on tvOS; a prewarm that ran app code before the user launched the app; and installing the instrumentation off the main thread after the app first became active.                                                                                                                                                                                                                 | `MAX_TIME_TO_UI_INIT` (1 minute) in `AppStartupTimer` |
| Backgrounded before the first frame              | The app entered the background after it became active but before its first frame was displayed. The display link pauses in the background, so the frame it reports is from the next time the app returned to the foreground. Applies to every start type.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | —                                                     |
| Prewarmed launch, when `dropPrewarmed` is `true` | The system prewarmed the process: `ActivePrewarm` was `1` (see [Prewarming](#prewarming)).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | —                                                     |
| Late installation                                | The instrumentation was installed after the app first became active, so the process can no longer get a `cold` or `warm` span, and the next activation is reported as `resume`. This is detected only when `install` runs on the main thread while the app is active. Later than that, while the app is inactive or in the background, it can't be told apart from a normal launch, because a scene-based app is in the background state during launch, so the next activation is reported as a launch from process start, and dropped if it's longer than `maxLaunchDuration`. Off the main thread, the next activation is reported as a launch from process start, which is dropped if it's longer than `maxLaunchDuration`. | —                                                     |

## Differences from Android

|                                               | Android                                                             | iOS                                                                                                         |
| --------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `start.type` meanings                         | Which parts of the app (process, activity) were reused              | Apple's launch and resume definitions: `cold` and `warm` are both new processes, and `resume` is any resume |
| Resume `start.type` value                     | `hot`                                                               | `resume`                                                                                                    |
| Process alive, UI recreated                   | `warm`                                                              | `resume`                                                                                                    |
| New process, recently run                     | `cold`                                                              | `warm`                                                                                                      |
| Launch start timestamp                        | When the instrumentation is installed                               | Process start, or the first app-code timestamp for prewarmed launches                                       |
| Resumes in multi-activity or multi-scene apps | Only emitted for single-activity apps                               | Emitted whenever the app as a whole returns from the background                                             |
| End timestamp                                 | `onActivityPostResumed`                                             | First frame displayed after the app becomes active                                                          |
| Prewarming                                    | Not applicable                                                      | Reported with `start.active_prewarmed`                                                                      |
| Per-screen lifecycle spans                    | `Created`, `Resumed`, `Paused`, … from the activity instrumentation | Not part of this module                                                                                     |

## References

- [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time): Apple's definitions of activation, launch, resume, and cold and warm launches
- [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence): Apple's description of prewarming
- [WWDC19: Optimizing App Launch](https://developer.apple.com/videos/play/wwdc2019/423/)
- [MXAppLaunchMetric](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric): the system's own launch and resume histograms, available through the [MetricKit](../MetricKit/README.md) instrumentation
- [App startup time](https://developer.android.com/topic/performance/vitals/launch-time): Android's definitions of cold, warm and hot starts, which this schema doesn't use
- [OpenTelemetry Android activity instrumentation](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity)
