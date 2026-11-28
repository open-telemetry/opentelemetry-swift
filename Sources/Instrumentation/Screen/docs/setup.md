# Setup

Register the processors every front end shares. See the [Screen README](../README.md).

## Registering the processors

Register providers before installing a front end; the first screen can appear at once.

```swift
import ScreenInstrumentation
import OpenTelemetrySdk

let tracerProvider = TracerProviderBuilder()
  .with(resource: resource)
  .add(spanProcessor: ScreenSpanProcessor())
  .add(spanProcessor: BatchSpanProcessor(spanExporter: spanExporter))
  .build()
OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

let loggerProvider = LoggerProviderBuilder()
  .with(resource: resource)
  .with(processors: [
    ScreenLogRecordProcessor(nextProcessor: BatchLogRecordProcessor(logRecordExporter: logExporter))
  ])
  .build()
OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
```

Put `ScreenSpanProcessor` before the exporter, and wrap the exporter in `ScreenLogRecordProcessor`, so the attribute is set before batching.

Then install [UIKit](../UIKit/README.md), mark [SwiftUI](../SwiftUI/README.md) screens, or both. Mixed apps leave `tracksHostingControllers` off to avoid reporting a view twice.

Navigation tracking is on by default. To turn it off, register a tracker before installing a front end:

```swift
ScreenTrackerProvider.register(screenTracker: ScreenTracker(tracksNavigation: false))
```

## Reading the current screen

```swift
let tracker = ScreenTrackerProvider.getInstance()
print(tracker.currentScreen ?? "nil", tracker.previousScreen ?? "nil")
```

To react to changes, observe `ScreenChangeNotification`; its object is the new name.
