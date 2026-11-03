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

A cold or warm launch is timed from process start to the first frame displayed after the app first becomes active, read with a `CADisplayLink` started on `UIApplication.didBecomeActiveNotification`, and is emitted once per process, for the first time the app reaches the foreground, unless the system started the process in the background. The end is the same quantity Apple's launch-time metric uses, which also runs to the first frame. The start isn't: Apple measures from the user tapping the icon, and says the system prepares the app for launch before handing control over to the app process, so the system's work before the process existed is outside this span.

| Child span              | Parent             | Runs from                                                            | To                                 |
| ----------------------- | ------------------ | -------------------------------------------------------------------- | ---------------------------------- |
| `app.start.pre_init`    | `app.start`        | Process start                                                        | `AppLaunchEnvironment` constructor |
| `app.start.app_init`    | `app.start`        | `AppLaunchEnvironment` constructor                                   | `didFinishLaunching` end           |
| `app.start.render`      | `app.start`        | `didFinishLaunching` end                                             | End of `app.start`                 |
| `app.start.scene_setup` | `app.start.render` | First scene connecting, or `didFinishLaunching` end if that was later | End of `app.start`                 |

`app.start.scene_setup` is floored at its parent's start, because UIKit connects a scene after `didFinishLaunching` and a child span must not begin before the span that holds it. `app.start.pre_init` isn't recorded for a prewarmed launch, which reports `app.start.pre_activation.duration` instead. A phase is only recorded if both of its timestamps are known, so `app.start.app_init` and `app.start.render` need the instrumentation installed before `didFinishLaunching` returns.

The boundary between `app.start.pre_init` and `app.start.app_init` is when this library's `AppLaunchEnvironment` C `constructor` ran, which is somewhere inside the app's static-initializer sequence rather than at its start or its end. Where it falls depends on where dyld placed this library among the app's images, so the split between the two phases isn't purely a property of the app and moves if the link order changes. On the [one device tested](#accuracy-compared-with-instruments) `app.start.app_init` was within +1.3 to +2.4 ms of the matching Instruments period, so on that app the constructor ran close to the end of static runtime initialization. That is a property of that app's link order, not something the library guarantees. This is not the `constructor` that bounds `app.start.page_ins.pre_initializer`, which samples the app's pages.

`app.start.app_init` covers the app's remaining static initializers, `main()`, `UIApplicationMain`, UIKit's bootstrap, `willFinishLaunching` and `didFinishLaunching`. It is the longest of the three phases: in the four launches the [integration tests](../../../Tests/IntegrationTests/README.md) record it was 46% to 59% of the launch, against 18% to 28% for `app.start.pre_init`. What inside it is slow isn't recorded; see [Not recorded yet](#not-recorded-yet).

If the app became active and then left before its first frame, the span ends at that moment with `app.start.outcome` set to `abandoned`. `app.start.duration` and `app.resume.duration` histograms record completed starts, in seconds. The metrics API can't set a unit, and the SDK only collects instruments that match a registered view.

`app.resume.type` is `hot`, `scene_reconnect` or `background_launched`. A resume starts when its scene connected, if one did, because UIKit connects it first, and otherwise at `willEnterForeground`. `app.resume.page_ins` is the process's page-ins across the resume, read at `willEnterForeground` and differenced at the end of the span, which is `opt_in` and carries [the same caveats](#measuring-cold-and-warm) as the launch page-in counts.

A resume also re-samples the pages the launch sampled, so it reports how much of the app's own code the system reclaimed while the app was away: `app.resume.text_pages.sampled`, `app.resume.text_pages.resident_at_end`, `app.resume.text_pages.paged_in` and `app.resume.text_pages.page_in_ratio`. The baseline is taken when the app enters the background, because reading it is one `mincore` call per sampled page and taking it on the way back would land inside the window being measured. A resume the app didn't enter the background before has no baseline, so a [`background_launched`](#resume) resume reports none of these. Unlike `app.resume.page_ins` these count only the app's code, which is the same measurement the launch's [`cold` and `warm`](#measuring-cold-and-warm) are decided from.

### Measuring `cold` and `warm`

The library samples up to 256 pages evenly spaced through the `__TEXT` segments of the app's images, which are the images in its bundle, or in the executable's directory if it isn't in one. It reads them with `mincore` in its initializer before `main()` and again when the app first becomes active, and reports:

`__TEXT` is the segment sampled because it holds the app's code and is read-only, so the kernel maps it once and, as Apple's [Mach-O overview](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html) puts it, can discard its pages and re-read them from disk whenever it needs to free memory. That is the behaviour these attributes measure. `__DATA` is writable and copy-on-write, so its pages are resident whether or not the launch read them and residency there would say nothing.

| Attribute                                 | Meaning                                                      |
| ----------------------------------------- | ------------------------------------------------------------ |
| `app.start.text_pages.total`             | Pages of the app's code that could be sampled                |
| `app.start.text_pages.sampled`           | Pages sampled, which is `total` capped at 256                |
| `app.start.text_pages.resident_at_end` | Sampled pages in the page cache when the app became active   |
| `app.start.text_pages.paged_in`        | Those not in it at this library's initializer                |
| `app.start.text_pages.page_in_ratio`         | `paged_in` divided by `resident_at_end`, from 0 to 1         |

`total` and `sampled` are both reported because the sample is capped at 256, so how much of the app it stands for varies by orders of magnitude. The demo app's device build has 413 samplable pages, which the sample covers 62% of. Across 150 iOS system apps the median is 6 pages, because their code lives in the shared cache rather than their bundles, so the sample is a census. Across 53 bundles in macOS `/Applications` the median is 10,830 pages, covered 2.4%, and Xcode's 158,554 are covered 0.16%. `total` is what says which case a reading comes from. A resume reports the same pair, since the total describes the binary rather than the window measured.

A _page in_ is the system reading a page of the app's code from disk into memory, which is what Apple's definition of a cold launch is about. The ratio is the share of the launch's code that was paged in. A launch is `cold` when the ratio is at least `coldPageInRatio`, which is 0.5 by default, and `warm` otherwise. On an iPhone 16 Pro Max, launches after a reboot had ratios from 0.70 to 0.72 and warm launches were at most 0.03. It doesn't reach 1, because some pages were already resident when this library's initializer ran. The share of `__TEXT` in memory can't be used directly, because a launch only touches part of the app's code, so even a warm launch can be far from 100%. Comparing the pages a launch ended up with to the ones it started with removes that difference between apps.

`mincore` reports the system's page cache, not what this process used, so these attributes describe what was cached. On one warm launch on an iPhone 16 Pro Max, Instruments showed the launch touching 55% of `__TEXT` while 93% of the sampled pages were resident. A cold launch's `paged_in` also includes pages the kernel read ahead.

A launch that can't be sampled, or with fewer than 16 resident pages when more were sampled, falls back to the [launch history](#launch-history-fallback) without these attributes, with `app.start.determined_by` set to `launch_history`, or is `prewarmed` if the system prewarmed it. Code in other images, such as system frameworks, isn't sampled. A debug build's simulator launch reads the Mac's page cache, so it says nothing about a device.

### Apple's launch phases

The Time Profile template's App Life Cycle timeline divides activity during app launch into process initialization, UIKit initialization, UIKit initial scene rendering, and initial frame rendering. The period labels below are the ones the comparison script reads from a trace; which label belongs to which division is inferred from the names, because Apple doesn't publish the mapping. These spans don't line up with the divisions:

| Apple's division              | Instruments period                             | This module                                                                                              |
| ----------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Process initialization        | `Initializing - Static Runtime Initialization` | `app.start.pre_init`, which ends at the `AppLaunchEnvironment` constructor and not at the end of the period |
| UIKit initialization          | `Launching - UIKit Initialization`             | No span. Part of `app.start.app_init`                                                                     |
| —                             | the period named for `didFinishLaunching`      | Only its end, as the boundary between `app.start.app_init` and `app.start.render`                         |
| UIKit initial scene rendering | —                                              | `app.start.scene_setup`, approximated from `UIScene.willConnectNotification` and never compared with Instruments |
| Initial frame rendering       | `Launching - Initial Frame Rendering`          | The tail of `app.start.render`, which is a superset running from `didFinishLaunching` to the first frame   |
| —                             | `Foreground - Active`                          | Starts at about the end of the span                                                                       |

Two of the four divisions have no span of their own: UIKit initialization is inside `app.start.app_init`, and initial frame rendering is the last part of `app.start.render`. The App Launch template also reports per-function attribution, thread states and dyld activity. These spans don't, and field telemetry can't.

### Accuracy compared with Instruments

Each launch below was recorded by this library and by the Instruments App Launch template at the same time, using [`Scripts/compare-app-launch-accuracy.py`](../../../Scripts/compare-app-launch-accuracy.py). They're Release builds of the demo app signed for development, so App Store encryption isn't covered, and Instruments slows the launch it's recording.

| Device                             | OS           | `__TEXT` pages | Cold | Warm | Partly cached |
| ---------------------------------- | ------------ | -------------- | ---- | ---- | ------------- |
| iPhone 16 Pro Max (`iPhone17,2`)   | iOS 26.6.2   | 261            | 4    | 6    | Not tested    |

Results on the iPhone 16 Pro Max, as the range across launches:

| Measurement                                                | Cold launches (4)  | Warm launches (6) |
| ---------------------------------------------------------- | ------------------ | ----------------- |
| Launch type agreed with Instruments                        | 4 of 4             | 6 of 6            |
| `app.start.text_pages.page_in_ratio`                          | 0.695 to 0.764     | 0 to 0.029        |
| `app.start.text_pages.paged_in`                         | 125 to 159         | 0 to 5            |
| Sampled pages Instruments saw read from disk               | 105 to 108         | 0 to 5            |
| `app.start.text_pages.resident_at_end`                  | 174 to 220         | 165 to 256        |
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

- The accuracy results were measured at about 98% sampling. The demo app has 261 pages of `__TEXT` and the library samples at most 256, so almost every page was in the sample. An app with more `__TEXT` than this one is sampled at a smaller share of its code, and nothing here says how much error that adds, including to `coldPageInRatio`, whose 0.5 default was chosen from ratios measured at almost complete sampling.
- Where a `CADisplayLink` is used, the span ends at its second tick after the app became active, and the library never checks that the app committed a frame holding its content. Across seven activations recorded in the iOS simulator that end was 19.5 to 40.0 ms after `didBecomeActive`, with no relation to how long the launch was, and the `app.start.render` phase on the [one device tested](#accuracy-compared-with-instruments) ran +24 to +34 ms against Instruments. Those two aren't the same measurement: that device has a 120 Hz display and the simulator ran at its host Mac's refresh rate, so they agree in milliseconds but not in frames. For a UIKit app whose first content frame is committed in the run-loop turn after it becomes active, that is the frame Apple's metric means, which includes the time to draw the views displayed on it. A first render that arrives later, such as a SwiftUI first layout or an async image decode, is undercounted, and nothing reports that it was.
- These durations have never been compared with the system's own measurement of the same app. [`MXAppLaunchMetric`](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric) reports a time-to-first-draw histogram for the same launches, which the [MetricKit](../MetricKit/README.md) instrumentation records as `metrickit.app_launch.time_to_first_draw_average`, so collecting both on one device is the cross-check to run before relying on these numbers.
- The initializers of images this library depends on run before it. If it's linked into the executable and the app's code is in a framework, pages those initializers bring in count as already in memory, so a cold launch can report a lower ratio.
- `cold` and `warm` only say whether the app's code was already in memory. The first launch after an install or update is `warm` if it was: on an iPhone 16 Pro Max, launches seconds after installing either read none of their `__TEXT` from disk or read most of what they touched, and it isn't known why they differ.
- Apple's [Mach-O overview](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html) says `__TEXT` and `__DATA` are the only segments "of interest in relation to performance", which is why only `__TEXT` is sampled. That document is retired, describes 4 KB pages rather than the 16 KB ones these devices use, and never mentions `__LINKEDIT` or the dyld shared cache. On a launch after a reboot, `__TEXT` was 2 to 5% of the disk reads Instruments recorded for the demo app, the rest being system frameworks, `__LINKEDIT` and data segments. So these attributes say whether the app's own code was cached, not how much the launch read.
- The sample is capped at 256 pages, which suits iOS but covers a large app thinly, and the risk there isn't sampling error: 256 pages hold the standard error on a proportion to 3.1% whatever the app's size, and the cold and warm clusters measured on a device were 22 standard errors apart. The risk is that thin coverage leaves few sampled pages resident, and a launch with fewer than 16 of them is classified from launch history instead, which it reports as `app.start.determined_by: launch_history`. No large app has been measured, so that's a prediction from the page counts, not an observation.
- App Store builds haven't been tested. Encrypted `__TEXT` might not report residency the same way as a development build, so compare a TestFlight build before relying on the 0.5 threshold.
- `app.start.page_ins.pre_initializer` and `app.start.page_ins.post_initializer` count the whole process, not the app's code, and are [higher than Instruments reports](#accuracy-compared-with-instruments) for a reason that isn't known. They also move by orders of magnitude between launches of the same binary: across the four launches the integration tests record, `pre_initializer` was 2, 111, 131 and 932, and `post_initializer` was 13, 102, 1,563 and 4,364. Both are `opt_in`, and are at most a rough comparison between launches, not a count of disk reads. `app.resume.page_ins` is the same counter over the resume window, so it carries the same caveats, and has never been compared with Instruments at all. `app.resume.text_pages.paged_in` measures the app's own code over the same window and doesn't have them, so prefer it. What drives it is memory pressure, not time suspended: on an iPhone 16 Pro Max, resumes after 25 and after 180 seconds suspended with nothing else running both reported 0, while a resume after 180 seconds suspended with Safari, Maps and Settings cycled through the foreground reported 302. Those three resumes took 460, 474 and 450 ms, so the pages counted didn't measurably slow any of them. The counter is task-wide, and there's no per-thread equivalent, so none of it can be attributed to work the first frame waited on.

### Not recorded yet

- `mainStart`, `didFinishLaunchingStart` and scene and delegate handler spans would need method swizzling, so they aren't part of the schema. Without them the longest phase isn't attributable: `app.start.app_init` holds both the app's static initializers and its app-delegate work, which Apple's launch-time guidance treats as two problems with different fixes, and which Apple's own App Life Cycle timeline keeps apart as process initialization and UIKit initialization. A high `app.start.app_init.duration` doesn't say which of them to look at.
- A launch the user leaves before the app first becomes active records no span, because that can't be told apart from a background launch.

## Platform support

| Platform       | Status      | Tested on                                                              | What's recorded                                                                                                                                                |
| -------------- | ----------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iOS            | Development | iPhone 16 Pro Max (`iPhone17,2`) on iOS 26.6.2, and an iPhone simulator | `cold`, `warm`, `resume` and `prewarmed`                                                                                                                     |
| iPadOS         | Untested    | —                                                                      | The same as iOS. Multi-window behaviour, where a second window connects or a scene the system discarded reconnects, has unit tests only                      |
| visionOS       | Untested    | —                                                                      | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`                                                                                    |
| Mac Catalyst   | Untested    | —                                                                      | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`                                                                                    |
| tvOS           | Untested    | —                                                                      | `cold`, `warm`, `resume`, and `prewarmed` if the system sets `ActivePrewarm`. A background launch isn't detected from the process's role                        |
| macOS          | Untested    | —                                                                      | Only `cold`, `warm` and `prewarmed`, ending at the first `NSApplication.didBecomeActiveNotification`, because macOS has neither `CADisplayLink` nor a background state |
| watchOS        | Unsupported | —                                                                      | Nothing. The API compiles, so shared code doesn't need a check, but `install` does nothing, `isInstalled` is always `false`, and no code runs at process start   |
| Linux, Windows | Unsupported | —                                                                      | The product isn't built, so it can't be added as a dependency                                                                                                  |

A dash means no telemetry has been collected from that platform: on an `Untested` row because nobody has run it there, and on an `Unsupported` row because there is nothing to collect. Those rows describe what the code would record, not what has been observed. The unit tests substitute their own lifecycle notifications and first-frame reader, so they cover the shared logic but verify no platform's own `PlatformLifecycle` defaults, including on the macOS host they run on. Only iOS has been exercised end to end:

- On the device, `Scripts/compare-app-launch-accuracy.py` recorded 4 cold and 6 warm launches against Instruments. See [Accuracy compared with Instruments](#accuracy-compared-with-instruments).
- On an iPhone simulator, the [integration tests](../../../Tests/IntegrationTests/README.md) record a launch, a resume, a background launch and a late install. They don't cover `prewarmed`, which the simulator can't produce, or the [launch history fallback](#launch-history-fallback), which has unit tests only: every launch they record reports `app.start.determined_by` as `page_sampling`.
- The simulator reads the Mac's page cache, so the launch types it reports say nothing about a device. Only the device run above supports the `cold` and `warm` thresholds.

When the system started the process in the background, the first time the app reaches the foreground is a [`resume`](#resume). Other launches the user can't have waited through are dropped by the [dropped-start rules](#dropped-starts).

## Debugging

Only errors are logged by default. To see why a start was or wasn't recorded, turn on debug mode, which logs every level:

```swift
OpenTelemetry.setDebugEnabled(true)
```

Messages go to `OpenTelemetry.instance.feedbackHandler` if one is registered. Without a handler they go to the unified log on Apple platforms, under the `io.opentelemetry.swift` subsystem with the module that logged them as the category, so a device build can be read with:

```sh
log stream --predicate 'subsystem == "io.opentelemetry.swift"' --level debug
```

Each line names the module it came from rather than repeating it in the message, so a dropped launch reads `[warn] MincoreLaunchInstrumentation: dropped a cold launch of 1829 ms, ...`.


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
| `coldPageInRatio`   | `0.5`                                | The share of sampled code a launch must page in from disk to be `cold` (`app.start.text_pages.page_in_ratio`), above 0 and at most 1. Apple describes cold and warm as a spectrum, so this is where the line is drawn. A value outside that range is reported as an error and replaced with the default. How high the ratio goes depends on the app, so check the ratios it reports before changing this.                  |

Spans also get `session.id` and `session.previous_id` when the [Sessions](../Sessions/README.md) span processor is registered.

## Start types

Apple's [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time) defines an _activation_ as the user clicking the app's icon or otherwise going back to the app. An activation is either a _launch_, when the process needs to start, or a _resume_, when the app already had a process alive, even if suspended. Apple calls a launch _warm_ when the system still has the app and its dependencies in memory, and _cold_ when it has to _page them in_ from disk, for example in a launch immediately after boot. Apple's wording covers the frameworks and daemons the app depends on, but only the app's own images are [sampled](#measuring-cold-and-warm), so the types below are decided from the app's code alone.

| Start type       | Apple term  | Meaning                                                                                                             |
| ---------------- | ----------- | ------------------------------------------------------------------------------------------------------------------- |
| `cold`           | Cold launch | A new process, and the launch had to page in the app's code from disk: its page-in ratio is at least `coldPageInRatio`. |
| `warm`           | Warm launch | A new process, and the app's code was already in memory: its page-in ratio is below `coldPageInRatio`.              |
| `prewarmed`      | Warm launch | A new process the system prewarmed. See [Prewarming](#prewarming).                                                  |
| `resume`         | Resume      | The app's process was still alive, even if suspended, and the app returns to the foreground. Recorded as `app.resume`. |

`cold`, `warm` and `prewarmed` are the values of `app.start.type`. `resume` is only a `launchTypes` option, because a resume is recorded as `app.resume` with an `app.resume.type` of its own.

Apple describes cold and warm launches as a spectrum, because how much the system still has cached depends on what else ran on the device. This library turns the spectrum into two types with its own threshold: a launch is `cold` when it paged in at least `coldPageInRatio` of the app's sampled code, which is [measured from the app's pages](#measuring-cold-and-warm). The threshold is configurable, because the ratios an app reports depend on the app.

The line is drawn on the device, so `app.start.type` is this library's verdict, not a property of the launch. The measurements it came from are reported as well, so a backend that wants a different line can recalculate from `app.start.text_pages.page_in_ratio` and ignore `app.start.type`. Two things limit that: `coldPageInRatio` itself isn't reported, so a span doesn't say which line produced its label, and the ratio is only present when `app.start.determined_by` is `page_sampling`, because a launch that fell back to [launch history](#launch-history-fallback) has no ratio at all.

### Launch history fallback

When a launch can't be sampled, there is no page-in ratio, so it is classified from what changed since the previous launch, and `app.start.determined_by` is `launch_history`. These are the causes after which the system is unlikely to have the app's code in memory, so the launch would have to page it in. It is `cold` when any of them is true, and `warm` otherwise:

- No previous launch is recorded, for example on the app's first launch after it's installed.
- The device booted after the previous launch, detected from a change in the kernel's boot session ID (`sysctl` `kern.bootsessionuuid`). If either launch's boot session ID couldn't be read, a change in the kernel boot time (`sysctl` `KERN_BOOTTIME`) of more than 1 second is used instead; setting the system clock also moves the boot time, so in that case it's treated like a reboot.
- The app's version (`CFBundleShortVersionString`) or build (`CFBundleVersion`) changed since the previous launch, so its new code isn't cached.
- The app was reinstalled since the previous launch, detected from a change in its bundle path, because the system puts every install in a new directory. The same build installed again is `cold` too, since its files were just rewritten. A record stored before this library kept the bundle path can't answer, so on the first launch after the library is upgraded the other causes decide.
- The boot time can't be read.

The previous launch's boot session ID, boot time, version, build and bundle path are stored in `UserDefaults.standard` under `io.opentelemetry.lifecycle.lastLaunchContext` when the instrumentation is installed, so the history stays current even for launches that are sampled. A launch is recorded in the history even if it never reaches the foreground, because the system still loaded the app's code.

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
| Clock stepped backward                           | The span's end is before its start. Every timestamp is wall clock, so setting the system clock back between process start and the first frame can do it, and a launch right after boot, which is Apple's example of a cold launch, is also when the system is most likely to set the clock from the network. The start is dropped rather than clamped, because its origin is unusable and a 0 ms sample would still enter the duration histogram. Applies to `app.resume` as well.                                                                                                                              | —                                                     |


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

- [Navigation Timing Level 2](https://www.w3.org/TR/navigation-timing-2/): the W3C `PerformanceNavigationTiming` model this schema follows, for the time origin, the `xxxStart` and `xxxEnd` pairs, `type` and `activationStart`
- [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time): Apple's definitions of activation, launch, resume, and cold and warm launches
- [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence): Apple's description of prewarming
- [WWDC19: Optimizing App Launch](https://developer.apple.com/videos/play/wwdc2019/423/)
- [Overview of the Mach-O executable format](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html): why `__TEXT` is the segment sampled, and that the kernel can discard its pages and re-read them when it needs memory. Retired, and it describes 4 KB pages rather than the 16 KB these devices use
- [WWDC22: Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/): current Apple material on `__LINKEDIT`, the exports trie and the launch-time fixups that the Mach-O overview above predates. Apple has no current prose documentation of the Mach-O format; `<mach-o/loader.h>` in the SDK is the authority the sampler matches against
- [`CADisplayLink`](https://developer.apple.com/documentation/quartzcore/cadisplaylink): how the first frame is read, and so what every launch and resume span ends at
- [`mincore` in xnu](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_mman.c): the syscall this module is named for, which reports whether a page is resident. Apple's online man page is no longer served, so `man 2 mincore` is the local reference
- [dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios) and [sentry-cocoa](https://github.com/getsentry/sentry-cocoa): the prior art this module is compared with for prewarm detection and for reading a background launch from the process's role
- [MXAppLaunchMetric](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric): the system's own launch and resume histograms, available through the [MetricKit](../MetricKit/README.md) instrumentation
- [App startup time](https://developer.android.com/topic/performance/vitals/launch-time): Android's definitions of cold, warm and hot starts, which this schema doesn't use
- [OpenTelemetry Android activity instrumentation](https://github.com/open-telemetry/opentelemetry-android/tree/main/instrumentation/activity)
- [Mach-O File Format](https://shell-storm.org/formats/macho.html)