### SwiftMetricsShim

Apple have created their own metrics API which has been adopted by a number of other packages including, but not limited to, Vapor - a prominent Server Side Swift platform.

This shim essentially redirects the data to the OpenTelemetry API functions.

 ```
let meter: Meter = // ... Your existing code to create a meter
let metrics = OpenTelemetrySwiftMetrics(meter: meter)
MetricsSystem.bootstrap(metrics)
```

If this is adopted, we may wish to add OpenTelemetry to the README of their package alongside SwiftPrometheus and StatsD. That would be a PR on their repo.

Tried to follow similar patterns to other products, but let me know if you need things changing!

Potentially this could be renamed/re-homed to an "Importers" directory to follow more closely with the "Exporters" systems. This would demonstrate a clear route forward for future bridges such as a swift-log product once we add support for logs.
