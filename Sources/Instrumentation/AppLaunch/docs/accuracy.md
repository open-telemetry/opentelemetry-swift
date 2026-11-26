# Accuracy and limits

What these measurements were checked against, how far they can be trusted, and what they leave out. See the [App Launch README](../README.md) for the spans themselves.

## Apple's launch phases


The Time Profile template's App Life Cycle timeline divides activity during app launch into process initialization, UIKit initialization, UIKit initial scene rendering, and initial frame rendering. The period labels below are the ones the comparison script reads from a trace. Which label belongs to which division is inferred from the names, because Apple publishes no mapping. These spans do not line up with the divisions:

| Apple's division              | Instruments period                             | This module                                                                                              |
| ----------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Process initialization        | `Initializing - Static Runtime Initialization` | `app.start.pre_init`, which ends at the `AppLaunchEnvironment` constructor and not at the end of the period |
| UIKit initialization          | `Launching - UIKit Initialization`             | No span. Part of `app.start.app_init`                                                                     |
| —                             | the period named for `didFinishLaunching`      | Only its end, as the boundary between `app.start.app_init` and `app.start.render`                         |
| UIKit initial scene rendering | —                                              | `app.start.scene_setup`, approximated from `UIScene.willConnectNotification` and never compared with Instruments |
| Initial frame rendering       | `Launching - Initial Frame Rendering`          | The tail of `app.start.render`, which is a superset running from `didFinishLaunching` to the first frame   |
| —                             | `Foreground - Active`                          | Starts at about the end of the span                                                                       |

Two of the four divisions have no span of their own: UIKit initialization sits inside `app.start.app_init`, and initial frame rendering is the last part of `app.start.render`. The App Launch template also reports per-function attribution, thread states and dyld activity. These spans report none of that, and field telemetry cannot.

### Where the phase boundary falls

This library's `AppLaunchEnvironment` C `constructor` marks the boundary between `app.start.pre_init` and `app.start.app_init`. It runs somewhere inside the app's static-initializer sequence rather than at its start or its end. Where it falls depends on where dyld placed this library among the app's images, so the split between the two phases moves with the link order and is not a property of the app alone.

On the [one device tested](#accuracy-compared-with-instruments), `app.start.app_init` ran within +1.3 to +2.4 ms of the matching Instruments period, so on that app the constructor ran close to the end of static runtime initialization. That reflects that app's link order; the library guarantees nothing about it.

A second `constructor` takes the `__TEXT` page sample and bounds `app.start.page_ins.before_text_sample`, and the order the two run in is undefined.

`app.start.app_init` covers the app's remaining static initializers, `main()`, `UIApplicationMain`, UIKit's bootstrap, `willFinishLaunching` and `didFinishLaunching`. It is the longest of the three phases: across the four launches the [integration tests](../../../../Tests/IntegrationTests/README.md) record, it held 46% to 59% of the launch, against 18% to 28% for `app.start.pre_init`. Nothing records which work inside it is slow; see [Not recorded yet](#not-recorded-yet).

## Accuracy compared with Instruments


This library and the Instruments App Launch template recorded each launch below at the same time, through [`Scripts/compare-app-launch-accuracy.py`](../../../../Scripts/compare-app-launch-accuracy.py). Every run used a Release build of the demo app signed for development, so these numbers cover no App Store encryption, and Instruments slows the launch it records.

| Device                             | OS           | `__TEXT` pages | Cold | Warm | Partly cached |
| ---------------------------------- | ------------ | -------------- | ---- | ---- | ------------- |
| iPhone 16 Pro Max (`iPhone17,2`)   | iOS 26.6.2   | 261            | 4    | 6    | Not tested    |

`__TEXT` pages is the count the trace reported for the app, which held one image at the time of these runs. The app has grown since; see [Known limits](#known-limits).

Results on the iPhone 16 Pro Max, given as the range across launches:

| Measurement                                                    | Cold launches (4)  | Warm launches (6) |
| -------------------------------------------------------------- | ------------------ | ----------------- |
| Launch type agreed with Instruments                            | 4 of 4             | 6 of 6            |
| `app.start.pages.text.page_in_ratio`                           | 0.695 to 0.764     | 0 to 0.029        |
| `app.start.pages.text.paged_in`                                | 125 to 159         | 0 to 5            |
| Sampled pages Instruments saw read from disk                   | 105 to 108         | 0 to 5            |
| `app.start.pages.text.resident_at_end`                         | 174 to 220         | 165 to 256        |
| Sampled pages Instruments saw the launch touch                 | 144                | 141 to 147        |
| `__TEXT` pages touched: estimate from the sample, minus actual | +0.2               | +0.2 to +0.3      |
| `app.start` duration                                           | 1,292 to 1,808 ms  | 923 to 1,143 ms   |
| Instruments launch duration                                    | 1,169 to 1,719 ms  | 850 to 1,061 ms   |
| `app.start` minus Instruments                                  | +85 to +123 ms     | +40 to +82 ms     |
| `app.start.pre_init` minus Instruments                         | +55 to +87 ms      | +35 to +58 ms     |
| `app.start.app_init` minus Instruments                         | +1.3 to +2.4 ms    | +1.4 to +2.0 ms   |
| `app.start.render` minus Instruments                           | +24 to +34 ms      | +3 to +31 ms      |
| `app.start.page_ins.before_text_sample` minus Instruments      | +50 to +125        | +16 to +60        |
| `app.start.page_ins.after_text_sample` minus Instruments       | +62 to +2,981      | +11 to +17        |

- Three cold launches followed a reboot and one followed an install. The warm launches include launches right after an install.
- The script calls a launch `warm` when the cache already held most of the `__TEXT` pages it touched before the first page came from disk. Instruments reports no launch type, so agreement here means the two readings are consistent.
- `paged_in` matched Instruments exactly on warm launches. It runs higher on cold launches, because it counts pages the launch never faulted on, which fits the kernel reading ahead.
- `resident_at_end` has no equivalent in Instruments, which sees this process's faults rather than the page cache.
- Instruments marks phases differently from these spans, so the phase differences show no winner.

These results cover no partly cached launch, where `coldPageInRatio` matters most, and no app with more than 256 pages of `__TEXT`, which this one barely reaches. To add a device, run the script with each `--mode` on it and add a row:

```sh
Scripts/compare-app-launch-accuracy.py --mode warm --launches 3
Scripts/compare-app-launch-accuracy.py --mode reboot --launches 3
```

## What has been verified

A platform marked `Untested` in the [platform support table](../README.md#platform-support) has had no telemetry collected from it, so its row describes what the code would record rather than what anyone has observed. The unit tests substitute their own lifecycle notifications and first-frame reader, so they cover the shared logic and verify no platform's own `PlatformLifecycle` defaults, including on the macOS host they run on. On watchOS `install` does nothing, `isInstalled` is always `false`, and no code runs at process start.

Only iOS has run end to end.

- On the device, `Scripts/compare-app-launch-accuracy.py` recorded 4 cold and 6 warm launches against Instruments. See [Accuracy compared with Instruments](#accuracy-compared-with-instruments).
- On an iPhone simulator, the [integration tests](../../../../Tests/IntegrationTests/README.md) record a launch, a resume, a background launch and a late install. They cover neither `prewarmed`, which the simulator cannot produce, nor the [launch history fallback](classification.md#launch-history-fallback), which has unit tests only: every launch they record reports `app.start.determined_by` as `page_sampling`.
- The simulator reads the Mac's page cache, so the launch types it reports say nothing about a device. Only the device run above supports the `cold` and `warm` thresholds.

## Known limits


- The accuracy results come from about 98% sampling, on a build of the demo app whose `__TEXT` held 261 pages in a single image, so the sample held 256 of its 260 samplable pages. The demo app has grown since, and its device build now has [413 samplable pages, covered 62%](classification.md#measuring-cold-and-warm), which these results also do not cover. The larger an app's `__TEXT`, the smaller the share of its code the sample reaches, and nothing here says how much error that adds — including to `coldPageInRatio`, whose 0.5 default came from ratios measured at almost complete sampling.
- Where the library uses a `CADisplayLink`, the span ends at its second tick after the app became active, and the library never checks that the app committed a frame holding its content. Across seven activations recorded in the iOS simulator, that end fell 19.5 to 40.0 ms after `didBecomeActive`, with no relation to the length of the launch, while the `app.start.render` phase on the [one device tested](#accuracy-compared-with-instruments) ran +24 to +34 ms against Instruments. Those two measure different things: that device has a 120 Hz display and the simulator ran at its host Mac's refresh rate, so they agree in milliseconds but not in frames. For a UIKit app that commits its first content frame in the run-loop turn after it becomes active, that frame is the one Apple's metric means, and it includes the time to draw the views on it. A first render that arrives later, such as a SwiftUI first layout or an async image decode, goes undercounted, and nothing reports that.
- Nobody has compared these durations with the system's own measurement of the same app. [`MXAppLaunchMetric`](https://developer.apple.com/documentation/metrickit/mxapplaunchmetric) reports a time-to-first-draw histogram for the same launches, which the [MetricKit](../../MetricKit/README.md) instrumentation records as `metrickit.app_launch.time_to_first_draw_average`, so collecting both on one device is the cross-check to run before relying on these numbers.
- The initializers of images this library depends on run before it does. When the executable links this library and the app's code lives in a framework, the pages those initializers bring in count as already in memory, so a cold launch can report a lower ratio.
- `cold` and `warm` say only whether the app's code was already in memory. The first launch after an install or update is `warm` when it was: on an iPhone 16 Pro Max, launches seconds after installing either read none of their `__TEXT` from disk or read most of what they touched, and nobody knows why they differ.
- Apple's [Mach-O overview](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html) says `__TEXT` and `__DATA` are the only segments "of interest in relation to performance", which is why the sample covers only `__TEXT`. That document is retired, describes 4 KB pages rather than the 16 KB ones these devices use, and never mentions `__LINKEDIT` or the dyld shared cache. On a launch after a reboot, `__TEXT` held 2 to 5% of the disk reads Instruments recorded for the demo app, the rest system frameworks, `__LINKEDIT` and data segments. So these attributes say whether the system cached the app's own code, not how much the launch read.
- The cap of 256 pages suits iOS but covers a large app thinly. Sampling error is not the risk there: 256 pages hold the standard error on a proportion to 3.1% whatever the app's size, and the cold and warm clusters measured on a device stood 22 standard errors apart. The risk is that thin coverage leaves few sampled pages resident, and a launch with fewer than 16 of them falls back to launch history and reports `app.start.determined_by: launch_history`. Nobody has measured a large app, so that is a prediction from the page counts rather than an observation.
- Nobody has tested an App Store build. Encrypted `__TEXT` may report residency differently from a development build, so compare a TestFlight build before relying on the 0.5 threshold.
- `app.start.page_ins.before_text_sample` and `app.start.page_ins.after_text_sample` count the whole process rather than the app's code, and run [higher than Instruments reports](#accuracy-compared-with-instruments) for a reason nobody has established. They also move by orders of magnitude between launches of the same binary: across the four launches the integration tests record, `before_text_sample` was 2, 111, 131 and 932, and `after_text_sample` was 13, 102, 1,563 and 4,364. Both are `opt_in`, and at most compare launches roughly; neither counts disk reads. `app.resume.page_ins` reads the same counter over the resume window, so it carries the same caveats, and nobody has compared it with Instruments at all. `app.resume.pages.text.paged_in` measures the app's own code over the same window and escapes those caveats, so prefer it. Memory pressure drives it, not time suspended: on an iPhone 16 Pro Max, resumes after 25 and after 180 seconds suspended with nothing else running both reported 0, while a resume after 180 seconds suspended with Safari, Maps and Settings cycled through the foreground reported 302. Those three resumes took 460, 474 and 450 ms, so the pages counted slowed none of them measurably. The counter covers the whole task and has no per-thread equivalent, so nothing attributes it to work the first frame waited on.

## Not recorded yet


- `mainStart`, `didFinishLaunchingStart` and scene and delegate handler spans would need method swizzling, so the schema leaves them out. Without them the longest phase resists attribution: `app.start.app_init` holds both the app's static initializers and its app-delegate work, which Apple's launch-time guidance treats as two problems with different fixes, and which Apple's own App Life Cycle timeline keeps apart as process initialization and UIKit initialization. A high `app.start.app_init.duration` does not say which of them to look at.
- A launch the user leaves before the app first becomes active records no span. The process's role shows it was no background launch, so the library could record it as an `abandoned` launch, and today it does not. It records the next activation as a resume.
