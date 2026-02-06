# KSCrash Instrumentation

Crash reporting instrumentation using [KSCrash](https://github.com/kstenerud/KSCrash) for OpenTelemetry Swift.

## Installation

Add the `Crash` product to your dependencies.

## Usage

```swift
import Crash

// Basic usage with defaults
let crashInstrumentation = KSCrashInstrumentation()

// Custom configuration
let config = KSCrashInstrumentationConfig()
config.maxStackTraceBytes = 50 * 1024  // 50 KB limit
config.enableOnDeviceSymbolication = true  // Enable symbolication (default: false)
config.enableSwapCxaThrow = true  // Better C++ exception traces
let crashInstrumentation = KSCrashInstrumentation(config: config)
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `maxStackTraceBytes` | 25 KB | Maximum size of stack trace in crash attributes |
| `enableSwapCxaThrow` | `false` | Better C++ exception stack traces (slight startup cost) |
| `enableSigTermMonitoring` | `false` | Monitor SIGTERM signals |

All `KSCrashConfiguration` options are available since `KSCrashInstrumentationConfig` extends it.

Note: On-device symbolication is disabled by default for performance. Crash reports use unsymbolicated format suitable for server-side symbolication.

## Crash Event Schema

Crashes are reported as log events with:

- `eventName`: `device.crash`
- `exception.type`: `crash`
- `exception.message`: Summary like `EXC_BREAKPOINT (SIGTRAP) detected on thread 0 at MyApp + 63552`
- `exception.stacktrace`: Apple-format crash report
- `session.id`: Session ID at crash time (recovered from crash context)

## Session Integration

Works with `Sessions` instrumentation to capture session context at crash time. The original session ID and timestamp are recovered when processing stored crashes.
