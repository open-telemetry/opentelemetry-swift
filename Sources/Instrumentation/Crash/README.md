# KSCrash Instrumentation

Crash reporting instrumentation using [KSCrash](https://github.com/kstenerud/KSCrash) for OpenTelemetry Swift.

## Installation

Add the `Crash` product to your dependencies.

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

## Configuration

`KSCrashInstrumentationConfig` extends `KSCrashConfiguration`, so every KSCrash option is available. Notable defaults this instrumentation overrides:

| Option | Default here | Notes |
|--------|--------------|-------|
| `maxStackTraceBytes` | 25 KB | Truncates `exception.stacktrace` to fit attribute size limits |
| `useOnDeviceSymbolication` | `false` | On-device symbolication is best-effort and can diverge from backend symbolication; prefer backend symbolication for crash grouping |
| `enableSigTermMonitoring` | `false` | SIGTERM is rarely a real crash signal |
| `enableSwapCxaThrow` | `false` | Off by default to keep launch cost low |

## Crash Event Schema

Crashes are reported as log events with:

- `eventName`: `device.crash`
- `exception.type`: `crash`
- `exception.message`: Summary like `EXC_BREAKPOINT (SIGTRAP) detected on thread 0 at MyApp + 63552`
- `exception.stacktrace`: Apple-format crash report
- `session.id`: Session ID at crash time (recovered from crash context)

## Session Integration

Works with `Sessions` instrumentation to capture session context at crash time. The original session ID and timestamp are recovered when processing stored crashes.
