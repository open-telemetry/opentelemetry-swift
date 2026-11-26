# Accuracy and limits

**The library measures the same launches Instruments does: three differently placed boundaries account for every millisecond of the +79 ms by which it reads longer, and none of the difference is measurement error.**

| Measurement | `MincoreLaunchInstrumentation` | `xctrace` | Difference | What the difference is |
| --- | -: | -: | -: | --- |
| Launch duration | 1,181 ± 278 ms | 1,102 ± 267 ms | +79 ± 21 ms | Boundary placement. Slope 1.039 ± 0.024, R² = 0.9957, so no proportional error. |
| &nbsp;&nbsp;`app.start.pre_init` | 524 ± 71 ms | 471 ± 63 ms | +53 ± 15 ms | Instruments' clock starts 54 ms after the kernel's process start. |
| &nbsp;&nbsp;`app.start.app_init` | 536 ± 243 ms | 534 ± 243 ms | +1.9 ± 0.4 ms | Static initialization ends 1.9 ms after this library's constructor. |
| &nbsp;&nbsp;`app.start.render` | 121 ± 56 ms | 97 ± 51 ms | +25 ± 9 ms | 2.95 display refresh periods. The display sets the floor. |
| `paged_in`, 6 warm | 0 to 5 pages | 0 to 5 pages | 0, exactly | Nothing to read, so the two agree to the page. |
| `paged_in`, 4 cold | 143 ± 16 pages | 107 ± 2 pages | +36 ± 17 pages | Kernel read-ahead, which `mincore` counts and a fault trace does not. |
| Cold / warm ratio | 0.721 / 0.005 | 1.000 / 0.017 | 10 of 10 agree | Different denominators. The comparator saturates and reuses the same 0.5 constant. |

The ± on each instrument is the spread across launches, which is real variation between launches rather than uncertainty; the ± on the difference is the spread of the paired difference, which is the measurement. `xctrace` figures come from the Instruments App Launch template, except the cold/warm ratio, which Instruments does not report and the comparison script [derives from the trace](#what-the-comparison-is-against-1).

Ten launches on one iPhone, each recorded by both instruments at once. [Method](#apparatus-and-procedure) · [raw data](#raw-data) · [conclusions](#conclusions) · [known limits](#known-limits). See the [App Launch README](../README.md) for the spans themselves.

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

### Apparatus and procedure

One iPhone 16 Pro Max (`iPhone17,2`, 120 Hz ProMotion display) running iOS 26.6.2, with a Release build of the demo app signed for development. Its `__TEXT` held 261 pages of 16 KB in a single image, of which the sample covered 256, or 98%.

[`Scripts/compare-app-launch-accuracy.py`](../../../../Scripts/compare-app-launch-accuracy.py) records each launch twice at once: this library writes a span, and the Instruments App Launch template writes a trace through `xctrace`. The script pairs them, and installs the app once before each run, so the first launch of a run follows an install. Ten launches were recorded: three after a reboot, three after a reinstall, two after the run's install, and two repeats.

Instruments slows the launch it records. Both instruments measure the same slowed launch, so that cancels in the paired difference.

The two instruments do not define the launch identically. The library starts at process start, read from the kernel's process table; Instruments starts at the first event it attributes to the process. The analysis below measures that difference rather than assuming it away.

### Raw data

Durations in milliseconds, page counts in 16 KB pages. The span columns are `app.start.pages.text.page_in_ratio` (ratio), `app.start.pages.text.resident_at_end` (resident) and `app.start.pages.text.paged_in` (paged_in); `disk reads` is the sampled pages Instruments saw read from disk.

| # | Type | Condition | xctrace | library | difference | ratio | resident | paged_in | disk reads |
| -: | --- | --- | -: | -: | -: | -: | -: | -: | -: |
| 1 | cold | after install | 1169 | 1292 | +122 | 0.764 | 208 | 159 | 105 |
| 2 | cold | after reboot | 1719 | 1808 | +89 | 0.718 | 174 | 125 | 108 |
| 3 | cold | after reboot | 1272 | 1357 | +85 | 0.705 | 190 | 134 | 108 |
| 4 | cold | after reboot | 1261 | 1350 | +89 | 0.695 | 220 | 153 | 108 |
| 5 | warm | after install | 901 | 941 | +40 | 0.029 | 170 | 5 | 5 |
| 6 | warm | after reinstall | 1061 | 1143 | +82 | 0.000 | 256 | 0 | 0 |
| 7 | warm | after reinstall | 850 | 923 | +73 | 0.000 | 165 | 0 | 0 |
| 8 | warm | after reinstall | 968 | 1036 | +68 | 0.000 | 165 | 0 | 0 |
| 9 | warm | repeat | 860 | 934 | +74 | 0.000 | 243 | 0 | 0 |
| 10 | warm | repeat | 963 | 1031 | +68 | 0.000 | 170 | 0 | 0 |

### Duration agreement

The library reads longer than Instruments on all ten launches (Figure 1). Taking the paired difference as the measurement:

| Set | n | Bias (ms) | SD (ms) | 95% CI of the mean | 95% limits of agreement |
| --- | -: | -: | -: | --- | --- |
| All | 10 | +79 | 21 | [+64, +94] | [+38, +120] |
| Cold | 4 | +96 | 18 | [+68, +124] | [+62, +131] |
| Warm | 6 | +68 | 14 | [+52, +83] | [+39, +96] |

The cold offset exceeds the warm one by 29 ms (Welch t = 2.72, df = 5.6, p < 0.05). A cold launch reads more from disk before this library's initializer runs, and that time falls inside the library's span but outside the Instruments period.

Regressing the library's duration on the Instruments duration across all ten launches gives

> library = (36 ± 27) ms + (1.039 ± 0.024) × xctrace,  R² = 0.9957, residual SD = 19 ms, n = 10

The slope's 95% interval is [0.984, 1.095], which contains 1, and the intercept's is [-27, 99] ms, which contains 0. The library tracks Instruments with no detectable proportional error: a launch twice as long reads twice as long, to the resolution of ten points. Plotting the difference against the mean of the two instruments gives r = +0.53 (t = +1.76 on 8 df), which also falls short of significance.

![Panel A plots the library's launch duration against the Instruments duration for ten launches, with a fitted line of slope 1.039 lying just above the identity line. Panel B is a Bland-Altman plot of the difference against the mean, with a bias of plus 79 milliseconds and limits of agreement at plus 38 and plus 120 milliseconds.](../img/accuracy-agreement.svg)


These data cannot separate a constant offset from a small proportional one. A pure offset of 79 ms and a 4% proportional term fit about equally well at n = 10. Separating them needs launches spanning a wider range than the 0.85 s to 1.72 s recorded here.

#### What the comparison is against

Unlike the launch type below, the durations compare against Instruments' own measurements. The script reads the App Launch template's named life-cycle periods for the launched pid and takes their edges, in [`compare-app-launch-accuracy.py:433`](../../../../Scripts/compare-app-launch-accuracy.py):

```python
initializer_end = static_init[1] + static_init[2]   # "Initializing - Static Runtime Initialization"
did_finish_end  = did_finish[1] + did_finish[2]     # the period naming didFinishLaunching
frame_end       = frame[1] + frame[2]               # "Launching - Initial Frame Rendering"
```

`xctrace record --launch` starts the process itself, so the trace's clock begins when Instruments first attributes an event to it, not at the kernel's process start. That makes the comparator independent, and it also makes the boundaries differ.

### Where the offset comes from

Three boundaries sit in different places. Writing b1, b2 and b3 for the gaps, the phase differences follow:

| Boundary | Library | Instruments | Gap | Enters |
| --- | --- | --- | -: | --- |
| Start | kernel process start | trace t0 | **b1** +54 ± 15 ms | `pre_init` |
| First phase end | this library's constructor | end of static runtime initialization | **b2** +1.9 ± 0.4 ms | `pre_init` and `app_init`, with opposite signs |
| `didFinishLaunching` | same event | same event | 0 | — |
| End | display-link second tick | end of initial frame rendering | **b3** +25 ± 9 ms | `render` |

![Panel A draws the library's span and the Instruments life-cycle periods on one wall clock. Instruments starts 54 milliseconds after the kernel's process start and its frame period ends 25 milliseconds before the display link reports, while the didFinishLaunching boundary is shared. The constructor boundary differs by under 2 milliseconds. Panel B plots that 25 millisecond end offset per launch in display refresh periods, clustering at 2.95 periods with a scatter of 1.05 periods.](../img/accuracy-offset.svg)

b2 cancels. The constructor runs inside static initialization, so it shortens `pre_init` and lengthens `app_init` by the same 1.9 ms, leaving the total untouched. The total offset is therefore b1 + b3 = 79.0 ms, which is the measured offset to the tenth of a millisecond.

That makes the `app_init` figure a measurement rather than an agreement. `app.start.app_init` does not merely come within +1.9 ± 0.4 ms of Instruments; that number **is** b2, the interval between this library's constructor and the end of static runtime initialization in this app. The script says as much at line 429: the two "compare differently defined boundaries", and the trace cannot say where the constructor ran. Its tightness, SD 0.4 ms across ten launches, says the constructor sits at a stable point in the link order, not that the two instruments agree.

b1 is larger on cold launches: 68 ± 7 ms against 46 ± 3 ms warm (Welch t = 2.77, p < 0.05). More pre-main disk work happens before Instruments' first attributable event when nothing is cached.

### The end timestamp is quantised by the display

b3 reads +25 ± 9 ms. One refresh period on a 120 Hz display is 8.33 ms, so that offset is **2.95 refresh periods, with a scatter of 1.05 periods**. A scatter of one period, rather than some unrelated figure, identifies the display refresh as the dominant term instead of measurement noise (Figure 3, panel B). The library cannot resolve the end of a launch more finely than the screen changes.

One period of the offset is structural: `DisplayLinkFirstFrameReader` ends on the second tick, because a frame committed before a refresh is displayed at the next one. The rest is the frame being drawn.

Launch 6 is the exception at +3.1 ms, 0.4 periods, and it carries the largest regression residual at −31 ms. One outlier in ten supports no conclusion beyond a first frame that landed earlier against the refresh cycle.

### Page counting

On all six warm launches `paged_in` equalled the Instruments count exactly: bias 0.0 pages, SD 0.0. On the four cold launches it ran +36 ± 17 pages high, range +17 to +54.

The two count different things. `mincore` reports the page cache; Instruments reports the faults this process took. A page the kernel reads ahead is resident without the process faulting on it, so the library counts it and Instruments does not. Exact agreement on warm launches, where there is no read-ahead, supports that reading: with nothing to read, the two instruments agree to the page.

### Launch classification

The library's ratio separates cleanly:

| Set | n | Mean ratio | SD | Range |
| --- | -: | -: | -: | --- |
| Cold | 4 | 0.721 | 0.031 | 0.695 to 0.764 |
| Warm | 6 | 0.005 | 0.012 | 0.000 to 0.029 |

The clusters stand 0.716 apart, which is 34 pooled standard deviations, or 23 binomial standard errors at n = 256. The 0.5 threshold sits 7.2 cold-cluster SD below the cold mean.

No launch fell between 0.03 and 0.70. These data therefore leave the threshold unconstrained across that interval: 0.5 is defensible, and so is any value from about 0.1 to 0.6. Only a partly cached launch would constrain it, and none was recorded.

#### What the comparison is against

Instruments reports no cold or warm label of its own. The comparison script derives one from the trace's virtual-memory events, in [`compare-app-launch-accuracy.py:490`](../../../../Scripts/compare-app-launch-accuracy.py):

```python
pre_cached = {page(event[2]) for event in hits if event[0] < first_read}
"launch_type": "warm" if len(pre_cached) >= COLD_RATIO * max(len(touched), 1) else "cold",
```

`pre_cached` counts the `__TEXT` pages the trace saw hit in the cache before the launch's first disk read, and `touched` counts every `__TEXT` page the launch touched. `COLD_RATIO` is 0.5, the same constant as `coldPageInRatio`. Complemented, the trace's measure is the fraction of touched pages that were **not** already cached, which is what the library's ratio also tries to express.

![Two strips on one axis compare the library's page-in ratio with the ratio derived from the Instruments trace. The library reads 0.721 on cold launches and 0.005 on warm ones. The trace measure saturates, reading exactly 1.000 on every cold launch and 0.000 on five of six warm ones. Both leave a wide empty interval around the 0.5 threshold.](../img/accuracy-classification.svg)

| Set | Library `page_in_ratio` | Trace 1 − `pre_cached` / `touched` |
| --- | -: | -: |
| Cold | 0.721 ± 0.031 | 1.000 ± 0.000 |
| Warm | 0.005 ± 0.012 | 0.017 ± 0.041 |

The two agree on all ten launches and correlate at r = 0.998, but neither figure means what it appears to mean.

They do not measure the same fraction. The library divides by `resident_at_end`, which counts pages resident when the app became active whether or not the launch touched them; the trace divides by `touched`, which counts only the pages the launch reached. On a cold launch the trace saw 146 touched pages and the library 174 to 220 resident, so the library's ratio is held below 1 by pages the launch never touched. That is why cold reads 0.721 against the trace's 1.000, and the gap is structural, not error.

The trace's measure is also close to binary. It read exactly 1.000 on all four cold launches and exactly 0.000 on five of the six warm ones, with a single intermediate value of 0.101. A measure that saturates cannot locate a threshold, and the correlation of 0.998 reflects only that both measures put the same launches at opposite ends. Ten launches agreeing therefore tests the direction of the classification, not the value of `coldPageInRatio`.

### Reproducing this

Run the script with each `--mode` on a device and add its rows to the raw data above. Each mode
installs the app first; `reboot` empties the page cache, which is the only way to force a cold
launch, and asks you to unlock the device after each reboot.

```sh
Scripts/compare-app-launch-accuracy.py --mode warm --launches 3
Scripts/compare-app-launch-accuracy.py --mode fresh-install --launches 3
Scripts/compare-app-launch-accuracy.py --mode reboot --launches 3
```

Each run writes its traces, spans and a `report.json` under `.build/app-launch-accuracy/<run>/`.
The analysis above reads those files, so re-running it on a new device needs no transcription.

### Uncertainty budget

| Term | Magnitude | Kind |
| --- | -: | --- |
| Start-point definition, process table against first traced event | ≈ +53 ms | systematic |
| Second-tick rule in the display-link read | +8.3 ms | systematic |
| Display refresh quantisation at 120 Hz | 8.3 ms wide, SD 2.4 ms | random |
| Scatter of the total difference | SD 21 ms | random |
| Ratio quantisation, 1 / `resident_at_end` | 0.004 to 0.006 | random |
| Binomial sampling error on the ratio, n = 256, p = 0.5 | 0.031 | random |

### Conclusions

1. The library's launch duration equals the Instruments duration plus an offset, with no detectable proportional error: slope 1.039 ± 0.024, R² = 0.9957, n = 10.
2. That offset is +79 ms, 95% CI +64 to +94, and decomposes exactly into two boundary gaps: +54 ms between the kernel's process start and the trace's clock, and +25 ms between Instruments' frame period and the display link. A third gap, the constructor against the end of static initialization, cancels.
3. Durations compare between launches on one device to about ±21 ms, 1 SD. They do not compare with Instruments in absolute terms unless the offset is subtracted.
4. `app.start.app_init` differs by +1.9 ± 0.4 ms, which measures where this library's constructor sits inside static runtime initialization rather than any disagreement between the instruments.
5. Cold and warm separate by 23 binomial standard errors, so the classification is not marginal. The trace-derived comparator agrees on all ten launches, but it saturates at 0 and 1 and applies the same 0.5 constant, so that agreement tests the direction of the classification rather than the threshold. Where the threshold sits inside the empty interval is unconstrained.
6. Every figure above rests on 10 launches, one app, one device, one OS version, and no partly cached launch. They characterise this configuration, not the method.

## What has been verified

A platform marked `Untested` in the [platform support table](../README.md#platform-support) has had no telemetry collected from it, so its row describes what the code would record rather than what anyone has observed. The unit tests substitute their own lifecycle notifications and first-frame reader, so they cover the shared logic and verify no platform's own `PlatformLifecycle` defaults, including on the macOS host they run on. On watchOS `install` does nothing, `isInstalled` is always `false`, and no code runs at process start.

Only iOS has run end to end.

- On the device, `Scripts/compare-app-launch-accuracy.py` recorded 4 cold and 6 warm launches against a launch type the script derives from the Instruments trace, Instruments reporting none itself. See [Accuracy compared with Instruments](#accuracy-compared-with-instruments).
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
