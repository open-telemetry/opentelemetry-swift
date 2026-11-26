# When a span is emitted

Which lifecycle events start and end each span, and the cases `MincoreLaunchInstrumentation` records nothing for. See the [App Launch README](../README.md) for the spans themselves.

## Child spans

`app.start.scene_setup` starts no earlier than its parent, because UIKit connects a scene after `didFinishLaunching` and a child span must not begin before the span that holds it. A prewarmed launch reports `app.start.pre_activation.duration` in place of `app.start.pre_init`. Each phase needs both of its timestamps, so `app.start.app_init` and `app.start.render` require the instrumentation installed before `didFinishLaunching` returns.

### What each phase holds

<dl>
<dt><code>app.start.pre_activation.duration</code>, prewarmed only</dt>
<dd>Process start to the first timestamp app code recorded. Reported as an attribute rather than a child span, because the span itself starts at the end of it: the system created the process before the user asked for the app, so the time belongs to the system, not to the launch the user waited through.</dd>
<dt><code>app.start.pre_init</code></dt>
<dd>Process start to this library's static initializer. The app is being loaded rather than running: dyld maps the executable, loads the libraries it depends on, binds their symbols, and runs the static initializers the link order placed before this one. The app's own launch code has not started.</dd>
<dt><code>app.start.app_init</code></dt>
<dd>This library's static initializer to the end of <code>didFinishLaunching</code>. The app finishes running its remaining static initializers, then runs its own launch code. This is the phase an app controls most directly.</dd>
<dt><code>app.start.render</code></dt>
<dd>The end of <code>didFinishLaunching</code> to the first frame. Building the first screen and drawing it.</dd>
<dt><code>app.start.scene_setup</code>, inside <code>render</code></dt>
<dd>The first scene connecting to the first frame. The part of rendering that waits on UIKit handing the app a scene, rather than on the app's own drawing.</dd>
<dt><code>app.resume.background.duration</code></dt>
<dd>How long the app sat in the background before this resume, ending where the span starts. Context for the resume rather than part of it, which is why a resume reports no phases: the process was alive and its UI built the whole time.</dd>
<dt><code>app.resume.scene_setup</code>, <code>scene_reconnect</code> only</dt>
<dd>The discarded scene reconnecting. Absent from a <code>hot</code> resume, which never lost its scene.</dd>
</dl>

### What the breakdown means

Which phase carries the cost is not obvious from the type's name. Across the ten launches measured on [one device](accuracy.md#apparatus-and-procedure), with medians rather than means because one cold launch ran long:

| Phase          | Cold median | Warm median | Difference |
| -------------- | ----------: | ----------: | ---------: |
| `pre_init`     |      509 ms |      512 ms |      −2 ms |
| `app_init`     |      674 ms |      396 ms |    +278 ms |
| `render`       |      181 ms |       86 ms |     +95 ms |
| `app.start`    |    1,354 ms |      986 ms |    +368 ms |

**A cold launch does not spend its extra time in `pre_init`.** That phase is the same either way, and its cold and warm ranges overlap completely, 474 to 653 ms against 425 to 596 ms. The cost lands in `app_init` and `render`, and the `render` ranges do not overlap at all: 172 to 203 ms cold against 54 to 91 ms warm.

The reason is that paging costs time when code runs, not when dyld maps it. Mapping a segment is cheap and lazy; the page faults arrive as the app executes its launch work and builds its first screen, which happens after this library's static initializer has already closed `pre_init`. So `app.start.pages.text.page_in_ratio` tells you the launch read the app's code from disk, and `app_init` and `render` tell you what that cost.

Treat these numbers as the shape to expect, not as thresholds. They come from one app on one device, with four cold launches and six warm, and an app that does more or less work before `didFinishLaunching` returns will divide the same total differently.

## `resume`


The library emits this when the app returns to the foreground from the background while its process is still alive. That includes the first time the app reaches the foreground after the system started it in the background, for example for a background fetch or a silent push.

The `app.resume.type` attribute can have the following values. Each describes a process that was already alive, so none of them is a launch.

<dl>
<dt><code>hot</code></dt>
<dd>A return to the foreground with the app's UI still built. This is the ordinary case, and it covers a launch the user left before its first frame, since that launch reached the background with its UI built.</dd>
<dt><code>scene_reconnect</code></dt>
<dd>A return to the foreground after the system discarded the app's scene, so UIKit connects a new one. The span starts at <code>UIScene.willConnectNotification</code> rather than at <code>willEnterForeground</code>, because UIKit connects the scene first.</dd>
<dt><code>background_launched</code></dt>
<dd>The first time the app reaches the foreground after the system started the process in the background. Note that such a resume has no page baseline, so it reports none of the <code>app.resume.pages.text.*</code> attributes.</dd>
</dl>

Either of two signals reports a background launch:

- Like Datadog, the role the system gave the process when it started it (`task_policy_get` with `TASK_CATEGORY_POLICY`), read before `main()`: `TASK_BACKGROUND_APPLICATION`, `TASK_DARWINBG_APPLICATION` or `TASK_NONUI_APPLICATION`, on a process the system did not [prewarm](classification.md#prewarming). Only iOS, iPadOS, visionOS and Mac Catalyst supply it. It is the signal that catches a background launch in a scene-based app, where UIKit posts no `didEnterBackgroundNotification` for one.
- `UIApplication.didEnterBackgroundNotification` arriving before the app first becomes active, which Apple's [About the background execution sequence](https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence) describes for an app without scenes. This also covers a user leaving the app before its launch finished.

When the role says background but the app becomes active without first entering the foreground, the role was wrong, and the library records the activation as a launch.

|       | Timestamp                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Start | `UIApplication.willEnterForegroundNotification`. When the system discarded the app's scene while the app was in the background, the new scene connects before the app enters the foreground, so the span starts at `UIScene.willConnectNotification` instead. That applies only when the app starts entering the foreground while UIKit handles the same event: a scene the system connects in the background, for example during a background launch, starts no resume. |
| End   | The first frame displayed after the next `UIApplication.didBecomeActiveNotification`                                                                                                                                                                                                                                                                                                                                                                                         |

The `UIApplication` notifications describe the app as a whole, so they behave the same with and without scenes.

The library emits no resume when:

- The app becomes active without first entering the background, for example after the user dismisses Control Center, Notification Center, a system alert or an incoming call. In those cases the app lost input focus only; it never left the foreground.
- A scene connects while the app is already in the foreground, for example when the user opens a second window on iPad.
- The app returns to the background before it becomes active. That abandons the activation.

## Dropped starts


The library emits no `app.start` or `app.resume` span in these cases:

| Case                                             | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Android equivalent                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| Launch longer than the maximum                   | The launch runs longer than `maxLaunchDuration` (60 seconds by default), measured from process start, or from when app code first ran for a prewarmed launch (see [Prewarming](classification.md#prewarming)), so the user cannot have waited through all of it. This catches a launch the system started in the background whose role the library could not read, for example on tvOS; a prewarm that ran app code before the user launched the app; and installing the instrumentation off the main thread after the app first became active.                                                                                                                                                                                                                 | `MAX_TIME_TO_UI_INIT` (1 minute) in `AppStartupTimer` |
| Late installation                                | Installation came after the app first became active, so the process can no longer earn a `cold` or `warm` span, and the library reports the next activation as `resume`. It detects this only when `install` runs on the main thread while the app is active. Later than that, while the app is inactive or in the background, nothing distinguishes it from a normal launch, because a scene-based app sits in the background state during launch, so the library reports the next activation as a launch from process start and drops it when it runs longer than `maxLaunchDuration`. Off the main thread, the library likewise reports the next activation as a launch from process start and drops it when it runs longer than `maxLaunchDuration`. | —                                                     |
| Clock stepped backward                           | The span's end falls before its start. Every timestamp is wall clock, so setting the system clock back between process start and the first frame produces this, and a launch right after boot — Apple's own example of a cold launch — is also when the system most likely sets the clock from the network. The library drops the start rather than clamping it, because its origin is unusable and a 0 ms sample would still enter the duration histogram. The same applies to `app.resume`.                                                                                                                              | —                                                     |


The library keeps an activation the app left before its first frame: its span ends when the app left, and `app.start.outcome` or `app.resume.outcome` reads `abandoned`.

## Debugging


The library logs only errors by default. To see why it recorded a start, or why it did not, turn on debug mode, which logs every level:

```swift
OpenTelemetry.setDebugEnabled(true)
```

Messages go to a handler registered with `OpenTelemetry.registerFeedbackHandler`. Without one they go to the unified log on Apple platforms, under the `io.opentelemetry.swift` subsystem with the module that logged them as the category, so this command reads a device build:

```sh
log stream --predicate 'subsystem == "io.opentelemetry.swift"' --level debug
```

Each line names the module it came from rather than repeating it in the message, so a dropped launch reads `[warn] MincoreLaunchInstrumentation: dropped a cold launch of 1829 ms, ...`.
