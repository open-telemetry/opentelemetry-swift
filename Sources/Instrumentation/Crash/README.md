# KSCrash Instrumentation

Crash reporting instrumentation using [KSCrash](https://github.com/kstenerud/KSCrash) for OpenTelemetry Swift.

## Installation

Add the `Crash` product to your dependencies. It pulls in KSCrash 2.6.x and is available on Apple platforms only.

## Usage

```swift
import Crash
import KSCrashFilters  // for AppleReportStyle

// Defaults
let crashInstrumentation = KSCrashInstrumentation()

// Custom configuration
let config = KSCrashInstrumentationConfig()
config.maxStackTraceBytes = 50 * 1024
config.reportStyle = .unsymbolicated         // default; backend should symbolicate
config.enableSwapCxaThrow = true             // better C++ traces; small startup cost
let crashInstrumentation = KSCrashInstrumentation(config: config)
```

Create it after registering your `LoggerProvider` and, if you use `Sessions`, your `SessionManager`: crashes stored by the previous run are reported as soon as the instrumentation is installed, and the current session is recorded with every crash.

KSCrash is installed once per process. Creating the instrumentation again is safe, but only the first configuration takes effect.

## Configuration

`KSCrashInstrumentationConfig` extends `KSCrashConfiguration`, so every KSCrash option is available. Options added or overridden here:

| Option | Default here | Notes |
|--------|--------------|-------|
| `maxStackTraceBytes` | 25 KB | Caps `exception.stacktrace` in UTF-8 bytes, see [Report size](#report-size) |
| `reportStyle` | `.unsymbolicated` | KSCrash's `AppleReportStyle`, see [Symbolication](#symbolication) |
| `enableSwapCxaThrow` | `false` | Off by default to keep launch cost low; turn on for actionable C++ exception traces |

### Report size

`exception.stacktrace` holds the Apple-format report, cut to `maxStackTraceBytes` at a character boundary. The report is cut from the end, so the header (process, OS version, exception type) and the thread backtraces are kept, while the `Binary Images` list at the end of the report is the first thing dropped. A full report is often several hundred KB, mostly binary images. A backend that symbolicates from the report needs the image UUIDs and load addresses for the frames it resolves, so raise the limit if your backend relies on them.

### Symbolication

KSCrash records each frame's symbol name on the device when the app crashes. `reportStyle` only chooses whether those names appear in `exception.stacktrace`. Swift and C++ names are demangled before the report is formatted.

The styles and demangling are KSCrash's own; its headers are the authoritative reference: [`KSCrashReportFilterAppleFmt.h`](https://github.com/kstenerud/KSCrash/blob/2.6.0/Sources/KSCrashFilters/include/KSCrashReportFilterAppleFmt.h) (`AppleReportStyle`) and [`KSCrashReportFilterDemangle.h`](https://github.com/kstenerud/KSCrash/blob/2.6.0/Sources/KSCrashDemangleFilter/include/KSCrashReportFilterDemangle.h). The table below summarizes them for KSCrash 2.6.0.

| `reportStyle` | Frames | Backend can symbolicate |
|---------------|--------|-------------------------|
| `.unsymbolicated` (default) | `<address> <load address> + <offset>` | All frames |
| `.partiallySymbolicated` | App frames as addresses, system and framework frames by name | App frames |
| `.symbolicatedSideBySide` | Address followed by `(symbol + offset)` | All frames |
| `.symbolicated` | `symbol + offset`, or the address when no name was found | Only frames left as addresses |

Keep the default if your backend symbolicates with the app's dSYMs: that gives function names with file and line numbers and keeps crash grouping stable. If your backend does no crash processing, use `.symbolicated` so the report is readable as sent.

Names resolved on the device are best-effort:

- They name the function and offset, never file and line numbers, which only exist in the dSYM.
- Release builds are normally stripped, so frames in your app resolve to the nearest symbol that survived stripping rather than the function that crashed.
- Results vary with optimization level, so the same crash can group differently than with backend symbolication.

## Crash Event Schema

Crashes are reported on the next launch as log events with:

- `eventName`: `device.crash`
- timestamp: when the crash happened, not when it was reported
- `exception.type`: the kind of crash, see below
- `exception.message`: the most descriptive text KSCrash recorded, see below
- `exception.stacktrace`: Apple-format crash report, see [Report size](#report-size)
- `session.id` / `session.previous_id`: the session that was current when the crash happened

`exception.type` and `exception.message` are read from KSCrash's structured report (its `Report` model), not parsed from the Apple-format text.

`exception.type` is one of:

- the exception name for an uncaught NSException (`NSRangeException`) or C++ exception (`std::runtime_error`)
- the Mach exception and its signal, as in the Apple report's `Exception Type` line (`EXC_BAD_ACCESS (SIGSEGV)`)
- the signal (`SIGABRT`) when there is no Mach exception
- KSCrash's report type otherwise, e.g. `termination` for an app that was killed without crashing

`exception.message` is the first of these that KSCrash recorded:

1. the exception's name and reason: `NSRangeException: *** -[__NSArrayI objectAtIndex:]: index 10 beyond bounds [0 .. 2]`
2. the message the Swift runtime (or another library) left when it trapped, e.g. `MyApp/Cart.swift:42: Fatal error: Unexpectedly found nil while unwrapping an Optional value`. Debug builds include the file and line; optimized builds often record a shorter message or none.
3. KSCrash's diagnosis, e.g. `Attempted to dereference null pointer.` or `The app exceeded its memory limit and was terminated by the OS.`
4. KSCrash's reason for the crash
5. otherwise the type and where it happened: the first frame in the app's own binaries (or the crashed frame if there is none) as module + offset from the start of the image, e.g. `SIGABRT at MyApp + 383012`

The message describes the crash for people. It is not meant as a grouping key: the same root cause can produce different text (an NSException reason or `fatalError` message can include values), and different causes can share text (every force unwrap reads the same). Backends should group on the symbolicated stack trace. If a report cannot be decoded, `exception.type` is `crash` and the message is taken from the Apple-format text.

See [Examples](#examples) for what real crashes are reported as.

## Session Integration

Works with `Sessions` instrumentation to capture session context at crash time: every session start updates the context KSCrash stores with a crash. When a stored crash is reported, its original session id, previous session id and timestamp are restored, so the crash is attributed to the session it happened in rather than the one that reports it. If the context cannot be recovered, the crash is timestamped when it is reported and gets the current session.
