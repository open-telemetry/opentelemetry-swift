### OpenTracingShim

This module requires the `OpenTracing` package trait:

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "3.0.0", traits: ["OpenTracing"])
```

An OpenTracing implementation that delegates to the OpenTelemetry SDK. Use OpenTracingShim to create tracers using this implementation.

