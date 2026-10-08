# KSCrash Instrumentation

Crash reporting instrumentation using [KSCrash](https://github.com/kstenerud/KSCrash) for OpenTelemetry Swift.

## Installation

Add the `Crash` product to your dependencies. It pulls in KSCrash 2.6.x and is available on Apple platforms only.

## Usage

```swift
import Crash

// Defaults
let crashInstrumentation = KSCrashInstrumentation()

// Custom configuration
let config = KSCrashInstrumentationConfig()
config.maxStackTraceBytes = 50 * 1024
config.useOnDeviceSymbolication = false      // default; backend should symbolicate
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
| `useOnDeviceSymbolication` | `false` | See [Symbolication](#symbolication) |
| `enableSwapCxaThrow` | `false` | Off by default to keep launch cost low; turn on for actionable C++ exception traces |

### Report size

`exception.stacktrace` holds the Apple-format report, cut to `maxStackTraceBytes` at a character boundary. The report is cut from the end, so the header (process, OS version, exception type) and the thread backtraces are kept, while the `Binary Images` list at the end of the report is the first thing dropped. A full report is often several hundred KB, mostly binary images. A backend that symbolicates from the report needs the image UUIDs and load addresses for the frames it resolves, so raise the limit if your backend relies on them.

### Symbolication

By default frames are left unsymbolicated (`<address> <load address> + <offset>`) for the backend to symbolicate with the app's dSYMs, which gives function names with file and line numbers and keeps crash grouping stable.

With `useOnDeviceSymbolication = true`, KSCrash resolves frames on the device from each binary's symbol table. This is best-effort:

- It names the function and offset, never file and line numbers, which only exist in the dSYM.
- Swift symbols are reported mangled (for example `$s14HackerNewsDemo...`).
- Release builds are normally stripped, so frames in your app resolve to the nearest symbol that survived stripping rather than the function that crashed.
- Results vary with optimization level, so the same crash can group differently than with backend symbolication.

## Crash Event Schema

Crashes are reported on the next launch as log events with:

- `eventName`: `device.crash`
- timestamp: when the crash happened, not when it was reported
- `exception.type`: `crash`
- `exception.message`: the exception type, crashed thread and top frame as module + offset, e.g. `EXC_BREAKPOINT (SIGTRAP) detected on thread 0 at libswiftCore.dylib + 1053200`. The per-crash instruction address is left out so the message groups.
- `exception.stacktrace`: Apple-format crash report, see [Report size](#report-size)
- `session.id` / `session.previous_id`: the session that was current when the crash happened

## Session Integration

Works with `Sessions` instrumentation to capture session context at crash time: every session start updates the context KSCrash stores with a crash. When a stored crash is reported, its original session id, previous session id and timestamp are restored, so the crash is attributed to the session it happened in rather than the one that reports it. If the context cannot be recovered, the crash is timestamped when it is reported and gets the current session.
