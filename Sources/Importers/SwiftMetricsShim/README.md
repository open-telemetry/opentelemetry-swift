### SwiftMetricsShim

This module requires the `SwiftObservabilityAPIBridges` package trait:

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "3.0.0", traits: ["SwiftObservabilityAPIBridges"])
```

Apple have created their own metrics API which has been adopted by a number of other packages including, but not limited to, Vapor - a prominent Server Side Swift platform.

This shim essentially redirects the data to the OpenTelemetry API functions.

 ```
let meter: Meter = // ... Your existing code to create a meter
let metrics = OpenTelemetrySwiftMetrics(meter: meter)
MetricsSystem.bootstrap(metrics)
```
