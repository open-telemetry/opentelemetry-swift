# App Launch Instrumentation

Status: development

Measures how long it takes the app to become usable after a user brings it to the foreground. `MincoreLaunchInstrumentation` reports each launch as an `app.start` span and each resume as an `app.resume` span, in the `io.opentelemetry.lifecycle` scope that [OpenTelemetry Android](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity) also uses. What each start type means follows Apple's definitions instead of Android's. See [Start types](#start-types).

Linking this library runs `mincore` before `main()`, so unlike a configuration option it can't be turned off at runtime. It has been tested on [one device](#accuracy-compared-with-instruments), and not with partly cached launches.

## `app.start` and `app.resume`

`MincoreLaunchInstrumentation` records a launch as one `app.start` span and a resume as one `app.resume` span, in the `io.opentelemetry.lifecycle` scope. The [federated registry](../SemanticConventions/model/swift/spans.yaml) is the authoritative definition. The schema follows W3C `PerformanceNavigationTiming`: a time origin, `xxxStart` and `xxxEnd` timestamps, a `type` and an `activationStart`. Each phase is a child span, because OpenTelemetry is deprecating span events.

| `app.start.type` | Span start                                                      | Span end              |
| ---------------- | --------------------------------------------------------------- | --------------------- |
| `cold`, `warm`   | Process start                                                   | First frame displayed |
| `prewarmed`      | When app code first ran, or process start if that can't be read | First frame displayed |

| Child span              | Parent             | Runs from                | To                       |
| ----------------------- | ------------------ | ------------------------ | ------------------------ |
| `app.start.pre_init`    | `app.start`        | Process start            | First initializer        |
| `app.start.app_init`    | `app.start`        | First initializer        | `didFinishLaunching` end |
| `app.start.render`      | `app.start`        | `didFinishLaunching` end | End of `app.start`       |
| `app.start.scene_setup` | `app.start.render` | First scene connecting   | End of `app.start`       |

`app.start.pre_init` isn't recorded for a prewarmed launch, which reports `app.start.pre_activation.duration` instead. A phase is only recorded if both of its timestamps are known, so `app.start.app_init` and `app.start.render` need the instrumentation installed before `didFinishLaunching` returns.

If the app became active and then left before its first frame, the span ends at that moment with `app.start.outcome` set to `abandoned`. `app.start.duration` and `app.resume.duration` histograms record completed starts, in seconds. The metrics API can't set a unit, and the SDK only collects instruments that match a registered view.

`app.resume.type` is `hot`, `scene_reconnect` or `background_launched`. A resume starts when its scene connected, if one did, because UIKit connects it first, and otherwise at `willEnterForeground`.

### Measuring `cold` and `warm`

The library samples up to 256 pages evenly spaced through the `__TEXT` segments of the app's images, which are the images in its bundle, or in the executable's directory if it isn't in one. It reads them with `mincore` in its initializer before `main()` and again when the app first becomes active, and reports:

| Attribute                                 | Meaning                                                      |
| ----------------------------------------- | ------------------------------------------------------------ |
| `app.start.sampled_pages.total`           | Pages sampled                                                |
| `app.start.sampled_pages.resident_at_end` | Sampled pages in the page cache when the app became active   |
| `app.start.sampled_pages.paged_in`        | Those not in it at this library's initializer                |
| `app.start.sampled_page_in_ratio`         | `paged_in` divided by `resident_at_end`, from 0 to 1         |

A _page in_ is the system reading a page of the app's code from disk into memory, which is what Apple's definition of a cold launch is about. The ratio is the share of the launch's code that was paged in. A launch is `cold` when the ratio is at least `coldPageInRatio`, which is 0.5 by default, and `warm` otherwise. On an iPhone 16 Pro Max, launches after a reboot had ratios from 0.70 to 0.72 and warm launches were at most 0.03. It doesn't reach 1, because some pages were already resident when this library's initializer ran. The share of `__TEXT` in memory can't be used directly, because a launch only touches part of the app's code, so even a warm launch can be far from 100%. Comparing the pages a launch ended up with to the ones it started with removes that difference between apps.

`mincore` reports the system's page cache, not what this process used, so these attributes describe what was cached. On one warm launch on an iPhone 16 Pro Max, Instruments showed the launch touching 55% of `__TEXT` while 93% of the sampled pages were resident. A cold launch's `paged_in` also includes pages the kernel read ahead.

A launch that can't be sampled, or with fewer than 16 resident pages when more were sampled, falls back to the [launch history](#launch-history-fallback) without these attributes, with `app.start.determined_by` set to `launch_history`, or is `prewarmed` if the system prewarmed it. Code in other images, such as system frameworks, isn't sampled. A debug build's simulator launch reads the Mac's page cache, so it says nothing about a device.

### Accuracy compared with Instruments

Each launch below was recorded by this library and by the Instruments App Launch template at the same time, using [`Scripts/compare-app-launch-accuracy.py`](../../../Scripts/compare-app-launch-accuracy.py). They're Release builds of the demo app signed for development, so App Store encryption isn't covered, and Instruments slows the launch it's recording.

| Device                             | OS           | `__TEXT` pages | Cold | Warm | Partly cached |
| ---------------------------------- | ------------ | -------------- | ---- | ---- | ------------- |
| iPhone 16 Pro Max (`iPhone17,2`)   | iOS 26.6.2   | 261            | 4    | 6    | Not tested    |
| Other devices                      | Not tested   |                |      |      |               |

Results on the iPhone 16 Pro Max, as the range across launches:

| Measurement                                                | Cold launches (4)  | Warm launches (6) |
| ---------------------------------------------------------- | ------------------ | ----------------- |
| Launch type agreed with Instruments                        | 4 of 4             | 6 of 6            |
| `app.start.sampled_page_in_ratio`                          | 0.695 to 0.764     | 0 to 0.029        |
| `app.start.sampled_pages.paged_in`                         | 125 to 159         | 0 to 5            |
| Sampled pages Instruments saw read from disk               | 105 to 108         | 0 to 5            |
| `app.start.sampled_pages.resident_at_end`                  | 174 to 220         | 165 to 256        |
| Sampled pages Instruments saw the launch touch             | 144                | 141 to 147        |
| `__TEXT` pages touched: estimate from the sample, minus actual | +0.2           | +0.2 to +0.3      |
| `app.start` duration                                       | 1,292 to 1,808 ms  | 923 to 1,143 ms   |
| Instruments launch duration                                | 1,169 to 1,719 ms  | 850 to 1,061 ms   |
| `app.start` minus Instruments                              | +85 to +123 ms     | +40 to +82 ms     |
| `app.start.pre_init` minus Instruments                     | +55 to +87 ms      | +35 to +58 ms     |
| `app.start.app_init` minus Instruments                     | +1.3 to +2.4 ms    | +1.4 to +2.0 ms   |
| `app.start.render` minus Instruments                       | +24 to +34 ms      | +3 to +31 ms      |
| `app.start.page_ins.pre_initializer` minus Instruments     | +50 to +125        | +16 to +60        |
| `app.start.page_ins.post_initializer` minus Instruments    | +62 to +2,981      | +11 to +17        |

- Three of the cold launches followed a reboot and one followed an install. The warm launches include ones right after an install.
- The script calls a launch `warm` if most of the `__TEXT` pages it touched were cached before the first one was read from disk. Instruments doesn't report a launch type, so agreement means the two are consistent.
- `paged_in` matched Instruments exactly on warm launches. It's higher on cold launches, which fits the kernel reading ahead, because it counts pages the launch didn't fault on.
- `resident_at_end` has no equivalent in Instruments, which sees this process's faults and not the page cache.
- Instruments marks phases differently from these spans, so the phase differences don't show which is right.

These results don't cover partly cached launches, where `coldPageInRatio` matters most, or apps with more than 256 pages of `__TEXT`, which this one barely reaches. To add a device, run the script with each `--mode` on it and add a row:

```sh
Scripts/compare-app-launch-accuracy.py --mode warm --launches 3
Scripts/compare-app-launch-accuracy.py --mode reboot --launches 3
```

### Known limits

- The initializers of images this library depends on run before it. If it's linked into the executable and the app's code is in a framework, pages those initializers bring in count as already in memory, so a cold launch can report a lower ratio.
- `cold` and `warm` only say whether the app's code was already in memory. The first launch after an install or update is `warm` if it was: on an iPhone 16 Pro Max, launches seconds after installing either read none of their `__TEXT` from disk or read most of what they touched, and it isn't known why they differ.
- App Store builds haven't been tested. Encrypted `__TEXT` might not report residency the same way as a development build, so compare a TestFlight build before relying on the 0.5 threshold.
- `app.start.page_ins.pre_initializer` and `app.start.page_ins.post_initializer` count the whole process, not the app's code, and are [higher than Instruments reports](#accuracy-compared-with-instruments) for a reason that isn't known. Use them to compare launches, not as disk reads.

### Not recorded yet

- `app.start.reason`, `app.resume.reason`, `app.start.previous_exit` and `app.resume.page_ins` are in the registry, but this library doesn't set them.
- `crashed` is only for a crash reporter to send on the next launch.
- `mainStart`, `didFinishLaunchingStart` and scene and delegate handler spans would need method swizzling, so they aren't part of the schema.
- A launch the user leaves before the app first becomes active records no span, because that can't be told apart from a background launch.

## Implementation status

Every span ends at the first frame displayed after the app becomes active, read with a `CADisplayLink`.

## Platform support

| Platform       | Status      | What's recorded                                                                                                                                                                           |
| -------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iOS, iPadOS    | Supported   | `cold`, `warm`, `resume` and `prewarmed`. Tested with real telemetry on the iOS simulator, except prewarming, which the simulator can't produce.                             |
| visionOS       | Supported   | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`. Not tested with real telemetry.                                                             |
| Mac Catalyst   | Supported   | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`. Not tested with real telemetry.                                                             |
| tvOS           | Supported   | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`. A background launch isn't detected from the process's role. Not tested with real telemetry. |
| macOS          | Partial     | Only `cold`, `warm` and `prewarmed`, ending at the first `NSApplication.didBecomeActiveNotification`, because macOS has neither `CADisplayLink` nor a background state.                                |
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
import MincoreLaunchInstrumentation

MincoreLaunchInstrumentation.install()
```

To change what's recorded, pass a configuration:

```swift
MincoreLaunchInstrumentation.install(
  configuration: AppLaunchInstrumentationConfiguration(
    launchTypes: [.cold, .warm, .resume],
    maxLaunchDuration: 60,
    coldPageInRatio: 0.5
  )
)
```

| Option              | Default                              | Description                                                                                                                                                                                                                                                                                    |
| ------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `launchTypes`       | `[.cold, .warm, .resume, .prewarmed]` | The [start types](#start-types) to record. Activations of other types don't produce spans, but are still tracked so that later ones are classified correctly. Leave out `.prewarmed` to drop [prewarmed](#prewarming) launches.                                                                |
| `maxLaunchDuration` | `60`                                 | The longest launch, in seconds, that's recorded. Longer launches are [dropped](#dropped-starts). It's measured from process start, or from when app code first ran for a prewarmed launch. The default matches Datadog.                                                                        |
| `coldPageInRatio`   | `0.5`                                | The share of sampled code a launch must page in from disk to be `cold` (`app.start.sampled_page_in_ratio`), above 0 and at most 1. Apple describes cold and warm as a spectrum, so this is where the line is drawn. A value outside that range is reported as an error and replaced with the default. How high the ratio goes depends on the app, so check the ratios it reports before changing this.                  |

Spans also get `session.id` and `session.previous_id` when the [Sessions](../Sessions/README.md) span processor is registered.

## Start types

Apple's [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time) defines an _activation_ as the user clicking the app's icon or otherwise going back to the app. An activation is either a _launch_, when the process needs to start, or a _resume_, when the app already had a process alive, even if suspended. Apple calls a launch _warm_ when the system still has the app and its dependencies in memory, and _cold_ when it has to _page them in_ from disk, for example in a launch immediately after boot.

| `app.start.type` | Apple term  | Meaning                                                                                                             |
| ---------------- | ----------- | ------------------------------------------------------------------------------------------------------------------- |
| `cold`           | Cold launch | A new process, and the launch had to page in the app's code from disk: its page-in ratio is at least `coldPageInRatio`. |
| `warm`           | Warm launch | A new process, and the app's code was already in memory: its page-in ratio is below `coldPageInRatio`.              |
| `prewarmed`      | Warm launch | A new process the system prewarmed. See [Prewarming](#prewarming).                                                  |
| `resume`         | Resume      | The app's process was still alive, even if suspended, and the app returns to the foreground. Recorded as `app.resume`. |

Apple describes cold and warm launches as a spectrum, because how much the system still has cached depends on what else ran on the device. This library turns the spectrum into two types with its own threshold: a launch is `cold` when it paged in at least `coldPageInRatio` of the app's sampled code, which is [measured from the app's pages](#measuring-cold-and-warm). The threshold is configurable, because the ratios an app reports depend on the app.

### Launch history fallback

When a launch can't be sampled, there is no page-in ratio, so it is classified from what changed since the previous launch, and `app.start.determined_by` is `launch_history`. These are the causes after which the system is unlikely to have the app's code in memory, so the launch would have to page it in. It is `cold` when any of them is true, and `warm` otherwise:

- No previous launch is recorded, for example on the app's first launch after it's installed.
- The device booted after the previous launch, detected from a change in the kernel's boot session ID (`sysctl` `kern.bootsessionuuid`). If either launch's boot session ID couldn't be read, a change in the kernel boot time (`sysctl` `KERN_BOOTTIME`) of more than 1 second is used instead; setting the system clock also moves the boot time, so in that case it's treated like a reboot.
- The app's version (`CFBundleShortVersionString`) or build (`CFBundleVersion`) changed since the previous launch, so its new code isn't cached.
- The app was reinstalled since the previous launch, detected from a change in its bundle path, because the system puts every install in a new directory. The same build installed again is `cold` too, since its files were just rewritten.
- The boot time can't be read.

The previous launch's boot session ID, boot time, version, build and bundle path are stored in `UserDefaults.standard` under `io.opentelemetry.lifecycle.lastLaunchContext` when the instrumentation is installed, so the history stays current even for launches that are sampled. A launch is recorded even if it never reaches the foreground, because the system still loaded the app's code.

A launch is timed from process start to the first frame displayed after the app first becomes active, read with a `CADisplayLink` started on `UIApplication.didBecomeActiveNotification`. This matches Apple's launch-time metric, which runs to the first frame. A cold or warm launch is emitted once per process, for the first time the app reaches the foreground, unless the system started the process in the background.

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

A launch is `prewarmed` when the `ActivePrewarm` environment variable was `1` when the process started. Apple doesn't document this variable, but Apple engineers have confirmed on the Developer Forums that the system sets it and that `UIApplication` clears it during launch. The module reads it from a C `constructor` function in the `AppLaunchEnvironment` target, which runs before `main()`.
Like Sentry and Datadog, this is the only signal used. A prewarmed launch without `ActivePrewarm` starts at process start, so it's usually longer than `maxLaunchDuration` and dropped.

Prewarming is independent of caching, so `app.start.prewarm.cache_state` says whether the app's code was `cold` or `warm` when the launch was sampled. A prewarmed launch's span starts at the time the `AppLaunchEnvironment` constructor ran, the earliest timestamp recorded by app code, instead of at process start.

The constructor time is a good start time because Apple's [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence) says prewarming "creates your process and loads the libraries your app links against, then suspends your process without allowing any application code to run". Earlier versions of that page said prewarming runs the launch sequence up to `UIApplicationMain`, which would include the constructor. If a system does that, the span is usually longer than `maxLaunchDuration` and is dropped.

## Dropped starts

No `app.start` or `app.resume` span is emitted in these cases:

| Case                                             | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Android equivalent                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| Launch longer than the maximum                   | A launch is longer than `maxLaunchDuration` (60 seconds by default), measured from process start, or from when app code first ran for a prewarmed launch (see [Prewarming](#prewarming)), so the user can't have waited through all of it. This covers a launch the system started in the background whose role couldn't be read, for example on tvOS; a prewarm that ran app code before the user launched the app; and installing the instrumentation off the main thread after the app first became active.                                                                                                                                                                                                                 | `MAX_TIME_TO_UI_INIT` (1 minute) in `AppStartupTimer` |
| Late installation                                | The instrumentation was installed after the app first became active, so the process can no longer get a `cold` or `warm` span, and the next activation is reported as `resume`. This is detected only when `install` runs on the main thread while the app is active. Later than that, while the app is inactive or in the background, it can't be told apart from a normal launch, because a scene-based app is in the background state during launch, so the next activation is reported as a launch from process start, and dropped if it's longer than `maxLaunchDuration`. Off the main thread, the next activation is reported as a launch from process start, which is dropped if it's longer than `maxLaunchDuration`. | —                                                     |


An activation the app left before its first frame is not dropped: its span ends when the app left, with `app.start.outcome` or `app.resume.outcome` set to `abandoned`.

## Differences from Android

|                                               | Android                                                             | iOS                                                                                                         |
| --------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Span name and attributes                      | `AppStart`, `start.type`                                            | `app.start` and `app.resume`, `app.start.type` and `app.resume.type`                                        |
| Meaning of the types                          | Which parts of the app (process, activity) were reused              | Apple's launch and resume definitions: `cold`, `warm` and `prewarmed` are new processes, and a resume is any resume |
| Process alive, UI recreated                   | `warm`                                                              | `app.resume`                                                                                                |
| New process, recently run                     | `cold`                                                              | `warm`                                                                                                      |
| Launch start timestamp                        | When the instrumentation is installed                               | Process start, or the first app-code timestamp for prewarmed launches                                       |
| Resumes in multi-activity or multi-scene apps | Only emitted for single-activity apps                               | Emitted whenever the app as a whole returns from the background                                             |
| End timestamp                                 | `onActivityPostResumed`                                             | First frame displayed after the app becomes active                                                          |
| Prewarming                                    | Not applicable                                                      | `prewarmed`                                                                                                 |
| Per-screen lifecycle spans                    | `Created`, `Resumed`, `Paused`, … from the activity instrumentation | Not part of this module                                                                                     |

## References

- [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time): Apple's definitions of activation, launch, resume, and cold and warm launches
- [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence): Apple's description of prewarming
- [WWDC19: Optimizing App Launch](https://developer.apple.com/videos/play/wwdc2019/423/)
- [MXAppLaunchMetric](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric): the system's own launch and resume histograms, available through the [MetricKit](../MetricKit/README.md) instrumentation
- [App startup time](https://developer.android.com/topic/performance/vitals/launch-time): Android's definitions of cold, warm and hot starts, which this schema doesn't use
- [OpenTelemetry Android activity instrumentation](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity)
