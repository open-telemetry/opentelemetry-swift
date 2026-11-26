# How the launch type is decided

How `MincoreLaunchInstrumentation` decides whether a launch is `cold`, `warm` or `prewarmed`, and what it falls back to when it cannot sample the app's pages. See the [App Launch README](../README.md) for the spans themselves.

## Measuring `cold` and `warm`


The library samples up to 256 pages evenly spaced through the `__TEXT` segments of the app's images, which are the images in its bundle, or in the executable's directory if it has no bundle. It reads them with `mincore` in its initializer before `main()` and again when the app first becomes active, and reports:

![Two-part diagram. Part one shows an image's segments — __TEXT, __DATA_CONST, __DATA and __LINKEDIT — with __TEXT highlighted as the only one sampled, because it holds read-only code the kernel discards and re-reads, although a cold launch reads all four from disk, and expands it into a strip of up to 256 evenly spaced sampled pages. Part two shows those pages as cells at two moments, at the library's constructor and when the app became active, for a cold launch and a warm one. In the cold launch 70 pages were already resident and 170 paged in, giving a ratio of 0.71; in the warm launch 233 were already resident and 7 paged in, giving 0.03. A scale at the bottom marks both ratios either side of the 0.5 coldPageInRatio threshold.](../img/text-page-sampling.svg)

The sample covers `__TEXT` because it holds the app's code and is read-only, so the kernel maps it once and, as Apple's [Mach-O overview](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html) puts it, can discard its pages and re-read them from disk whenever it needs to free memory. These attributes measure that behaviour. `__DATA` is writable and copy-on-write, so its pages are resident whether or not the launch read them, and residency there would say nothing. A cold launch reads the other segments from disk as well, so they cost launch time; the sample leaves them out because it cannot measure them, not because they are free.

`__LINKEDIT` is the exception: it is read-only and file-backed like `__TEXT`, so `mincore` would measure it the same way. It holds link metadata rather than the app's code, and the ratios measured on device are a property of `__TEXT` pages, so sampling it would need its own counts under `app.start.pages.linkedit.*` and its own threshold.

<dl>
<dt><code>app.start.pages.text.total</code></dt>
<dd>An integer representing the pages of the app's code that could be sampled.</dd>
<dt><code>app.start.pages.text.sampled</code></dt>
<dd>An integer representing the pages sampled, which is <code>total</code> capped at 256.</dd>
<dt><code>app.start.pages.text.resident_at_end</code></dt>
<dd>An integer representing the sampled pages in the page cache when the app became active.</dd>
<dt><code>app.start.pages.text.paged_in</code></dt>
<dd>An integer representing the sampled pages absent from the page cache when this library's initializer ran.</dd>
<dt><code>app.start.pages.text.page_in_ratio</code></dt>
<dd>A number from 0 to 1 representing <code>paged_in</code> divided by <code>resident_at_end</code>.</dd>
</dl>

The library reports both `total` and `sampled`, because the cap of 256 makes the share of the app a sample stands for vary by orders of magnitude. The demo app's device build has 413 samplable pages, which the sample covers 62% of. That is the build in the repository now, not the smaller one the [accuracy results](accuracy.md#accuracy-compared-with-instruments) came from.

Across 150 iOS system apps the median is 6 pages, because their code lives in the shared cache rather than their bundles, so the sample is a census. Across 53 bundles in macOS `/Applications` the median is 10,830 pages, covered 2.4%, and Xcode's 158,554 are covered 0.16%.

`total` tells you which case a reading comes from. A resume reports the same pair, since the total describes the binary rather than the window measured.

A _page in_ is the system reading a page of the app's code from disk into memory, which is what Apple's definition of a cold launch turns on. The ratio is the share of the launch's code the system paged in. A launch is `cold` when the ratio reaches `coldPageInRatio`, which is 0.5 by default, and `warm` below it. On an iPhone 16 Pro Max, launches after a reboot reported ratios from 0.70 to 0.72, and warm launches reported at most 0.03.

The ratio never reaches 1, because some pages were already resident when this library's initializer ran. The share of `__TEXT` in memory cannot serve directly, because a launch touches only part of the app's code, so even a warm launch can fall far short of 100%.

Comparing the pages a launch ended up with against the ones it started with removes that difference between apps.

`mincore` reports the system's page cache, not what this process used, so these attributes describe what was cached. On one warm launch on an iPhone 16 Pro Max, Instruments showed the launch touching 55% of `__TEXT` while 93% of the sampled pages were resident. A cold launch's `paged_in` also counts pages the kernel read ahead.

A launch the library cannot sample, or one with fewer than 16 resident pages when it sampled more, falls back to the [launch history](#launch-history-fallback) without these attributes and reports `app.start.determined_by` as `launch_history` — or reports `prewarmed` if the system prewarmed it. A prewarmed launch takes its name from its environment variable rather than from the sample, so `app.start.determined_by` reads `prewarm_flag` either way, and the attributes above appear on the span whenever the sample succeeded. The sample skips code in other images, such as system frameworks. A debug build's simulator launch reads the Mac's page cache, so it says nothing about a device.

A resume re-samples the pages the launch sampled, so it reports how much of the app's own code came back into memory while the app was away: `app.resume.pages.text.sampled`, `app.resume.pages.text.resident_at_end`, `app.resume.pages.text.paged_in` and `app.resume.pages.text.page_in_ratio`. The baseline comes from the moment the app enters the background, because reading it costs one `mincore` call per sampled page and taking it on the way back would land inside the window being measured. So `paged_in` is the difference between two snapshots rather than everything the system reclaimed: a page resident when the app left, reclaimed while it was suspended and read back during the resume, is resident in both snapshots and counts for nothing.

A resume that followed no background has no baseline, so a [`background_launched`](lifecycle.md#resume) resume reports none of these. Unlike `app.resume.page_ins`, these count only the app's code, the same measurement that decides a launch's [`cold` and `warm`](#measuring-cold-and-warm).

`app.resume.page_ins` holds the process's page-ins across the resume, read at `willEnterForeground` and differenced at the end of the span. It is `opt_in` and carries [the same caveats](#measuring-cold-and-warm) as the launch page-in counts.

## Launch history fallback


When the library cannot sample a launch, or when fewer than 16 of its sampled pages are resident at the end — too few for a ratio to mean anything, unless that is all the app has — the span carries no page-in ratio, so what changed since the previous launch classifies the launch and `app.start.determined_by` reads `launch_history`. A prewarmed launch is the exception: it reports `prewarm_flag` rather than falling back here, because the environment variable already names its type. The causes below each leave the system unlikely to hold the app's code in memory, so the launch would have to page it in. Any one of them makes the launch `cold`, and otherwise it is `warm`:

- No previous launch is recorded, for example on the app's first launch after it's installed.
- The device booted after the previous launch, which a change in the kernel's boot session ID (`sysctl` `kern.bootsessionuuid`) reports. When either launch's boot session ID could not be read, a change in the kernel boot time (`sysctl` `KERN_BOOTTIME`) of more than 1 second stands in; setting the system clock also moves the boot time, so that case counts as a reboot.
- The app's version (`CFBundleShortVersionString`) or build (`CFBundleVersion`) changed since the previous launch, so its new code isn't cached.
- Someone reinstalled the app since the previous launch, which a change in its bundle path reports, because the system puts every install in a new directory. Installing the same build again is `cold` too, since the system just rewrote its files. A record stored before this library kept the bundle path cannot answer, so on the first launch after you upgrade the library the other causes decide.
- The boot time can't be read.

Installing the instrumentation stores the previous launch's boot session ID, boot time, version, build and bundle path in `UserDefaults.standard` under `io.opentelemetry.lifecycle.lastLaunchContext`, so the history stays current even for launches the library samples. The history records a launch even when it never reaches the foreground, because the system still loaded the app's code.

## Prewarming


On iOS 15 and later the system can prewarm an app: it creates the process ahead of time and suspends it before any app code runs, then resumes it when the user launches the app. A prewarmed launch's process start time can fall minutes or hours before the user tapped the icon, so the span cannot start there.

A launch is `prewarmed` when the `ActivePrewarm` environment variable read `1` at process start. Apple documents no such variable, but Apple engineers have confirmed on the Developer Forums that the system sets it and that `UIApplication` clears it during launch. The module reads it from a C `constructor` function in the `AppLaunchEnvironment` target, which runs before `main()`.

Like Sentry and Datadog, the library relies on that signal alone. A prewarmed launch without `ActivePrewarm` starts at process start, so it runs longer than `maxLaunchDuration` and the library drops it.

Prewarming is independent of caching, so `app.start.prewarm.cache_state` reports whether the app's code was `cold` or `warm` on a launch the library sampled. A prewarmed launch's span starts when this library's static initializer ran, the earliest timestamp app code records, rather than at process start.

The constructor time serves as a start time because Apple's [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence) says prewarming "creates your process and loads the libraries your app links against, then suspends your process without allowing any application code to run". Earlier versions of that page said prewarming runs the launch sequence up to `UIApplicationMain`, which would include the constructor. On a system that does that, the span runs longer than `maxLaunchDuration` and the library drops it.

## Differences from Android


|                                               | Android                                                             | iOS                                                                                                         |
| --------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Span name and attributes                      | `AppStart`, `start.type`                                            | `app.start` and `app.resume`, `app.start.type` and `app.resume.type`                                        |
| Meaning of the types                          | Which parts of the app (process, activity) the system reused         | Apple's launch and resume definitions: `cold`, `warm` and `prewarmed` are new processes, and a resume is any resume |
| Process alive, UI recreated                   | `warm`                                                              | `app.resume`                                                                                                |
| New process, recently run                     | `cold`                                                              | `warm`                                                                                                      |
| Launch start timestamp                        | When the app installs the instrumentation                           | Process start, or the first app-code timestamp for prewarmed launches                                       |
| Resumes in multi-activity or multi-scene apps | Single-activity apps only                                           | Emitted whenever the app as a whole returns from the background                                             |
| End timestamp                                 | `onActivityPostResumed`                                             | First frame displayed after the app becomes active                                                          |
| Prewarming                                    | Not applicable                                                      | `prewarmed`                                                                                                 |
| Per-screen lifecycle spans                    | `Created`, `Resumed`, `Paused`, … from the activity instrumentation | Not part of this module                                                                                     |

## See also

- [About the app launch sequence](https://developer.apple.com/documentation/uikit/about-the-app-launch-sequence): Apple's description of prewarming
- [WWDC19: Optimizing App Launch](https://developer.apple.com/videos/play/wwdc2019/423/)
- [WWDC22: Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/): current Apple material on `__LINKEDIT`, the exports trie and the launch-time fixups that the Mach-O overview below predates. Apple has no current prose documentation of the Mach-O format; `<mach-o/loader.h>` in the SDK is the authority the sampler matches against
- [Overview of the Mach-O executable format](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html): why the sample covers `__TEXT`, and that the kernel can discard its pages and re-read them when it needs memory. Retired, and it describes 4 KB pages rather than the 16 KB these devices use
- [Mach-O File Format](https://shell-storm.org/formats/macho.html)
- [`mincore` in xnu](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_mman.c): the syscall this module is named for, which reports whether a page is resident. Apple's online man page is no longer served, so `man 2 mincore` is the local reference
- [dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios) and [sentry-cocoa](https://github.com/getsentry/sentry-cocoa): the prior art this module follows for prewarm detection and for reading a background launch from the process's role
- [App startup time](https://developer.android.com/topic/performance/vitals/launch-time): Android's definitions of cold, warm and hot starts, which this schema does not use
