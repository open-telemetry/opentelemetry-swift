# SignPost Integration

This package creates `os_signpost` `begin` and `end` calls when spans are started or ended. It allows automatic integration of applications
instrumented with opentelemetry to show their spans in a profiling app like `Instruments`. It also exports the `OSLog` it uses for posting so the user can add extra signpost events. This functionality is shown in `Simple Exporter` example

## Version Notice

- **iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+**:
  Use **`OSSignposterIntegration`**, which utilizes the modern `OSSignposter` API for improved efficiency and compatibility.
- **iOS 13-14, tvOS 13-14**:
  Use **`SignPostIntegration`**, which relies on the traditional `os_signpost` API.

These ranges follow the deployment targets in [`Package.swift`](../../../Package.swift).
The legacy class is annotated for iOS/tvOS 12, but this package requires iOS/tvOS 13 or later.

The legacy processor is not available on watchOS or visionOS.

## Usage 

Add the appropriate span processor to your `TracerProviderSdk`, based on your deployment target:

```swift
let tracerProvider = TracerProviderSdk()
```

### For iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+:

```swift
tracerProvider.addSpanProcessor(OSSignposterIntegration())
```

### For older systems

```swift
tracerProvider.addSpanProcessor(SignPostIntegration())
```

### Or, to select automatically at runtime:

```swift
if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
    tracerProvider.addSpanProcessor(OSSignposterIntegration())
} else {
    #if !os(watchOS) && !os(visionOS)
    tracerProvider.addSpanProcessor(SignPostIntegration())
    #endif
}
```

Then register the provider with `OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)`.

### Custom logs and MetricKit

Both processors accept an `OSLog` through `init(log:)`. The zero-argument initializers still use
the `OpenTelemetry` subsystem and `.pointsOfInterest` category. Passing `OSLog.disabled`
disables signpost output without disabling span export.
The supplied log replaces the default destination; signposts are not also sent to `.pointsOfInterest`.

On iOS 13+, Mac Catalyst 13.1+, macOS 12+, and visionOS 1+, you can pass a log created by
[`MXMetricManager.makeLogHandle(category:)`](https://developer.apple.com/documentation/metrickit/mxmetricmanager/makeloghandle(category:)).
MetricKit is not available on tvOS or watchOS.

Apple limits how many MetricKit signposts it processes. Use this log only for critical sections,
not every span from app-wide instrumentation. This example keeps the processor on a separate
provider rather than registering it globally. Only use `criticalTracer` for those operations;
MetricKit does not guarantee complete telemetry.

```swift
import MetricKit
import OpenTelemetrySdk
import SignPostIntegration

let criticalSpanProvider = TracerProviderSdk()
let log = MXMetricManager.makeLogHandle(category: "OpenTelemetrySpans")
if #available(iOS 15, macOS 12, *) {
    criticalSpanProvider.addSpanProcessor(OSSignposterIntegration(log: log))
} else {
    #if !os(visionOS)
    criticalSpanProvider.addSpanProcessor(SignPostIntegration(log: log))
    #endif
}
let criticalTracer = criticalSpanProvider.get(instrumentationName: "CriticalOperations")
```

This sends span intervals to the supplied log; it does not subscribe to MetricKit payloads.
Both processors use the signpost name `Span`; the OpenTelemetry span name is included in the
public message, not the signpost name. MetricKit groups signpost metrics by name and category,
so this does not create separate metrics for each OpenTelemetry span name.

MetricKit resource measurements such as CPU time, memory usage, and logical writes require
`mxSignpost`, which these processors do not call. Passing a MetricKit log alone does not populate
those measurements. See [Apple's MetricKit signpost guidance](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit).
