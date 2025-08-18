### SwiftMetricsShim

Apple have created their own metrics API which has been adopted by a number of other packages including, but not limited to, Vapor - a prominent Server Side Swift platform.

This shim essentially redirects the data to the OpenTelemetry API functions.

 ```
let meter: Meter = // ... Your existing code to create a meter
let metrics = OpenTelemetrySwiftMetrics(meter: meter)
MetricsSystem.bootstrap(metrics)
```
