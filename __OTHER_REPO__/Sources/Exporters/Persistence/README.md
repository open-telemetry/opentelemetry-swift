# Persistence Exporter

The Persistence Exporter is not an actual exporter by itself, but an exporter decorator. It decorates a given exporter by persisting the exported data to the disk first, and then proceeds to forward it to the decorated exporter. The goal is to allow dealing with situations where telemetry data is generated in an environment that can't guarantee stable export.

An example use case is mobile apps that operate while the device has no network connectivity. With the Persistence Exporter decorating the actual exporters used by the app, telemetry can be collected while the device is offline. Later - possibly after the app is terminated and relaunched - when network connectivity is back the collected telemetry data can be picked up from the disk and exported.

The Persistence Exporter provides decorators for MetricExporter and SpanExporter. The decorators handle exported data by:

- Asynchronously serializing and writing the exported data to the disk to a specified path.
- Asynchronously picking up persisted data, deserializing it, and forwarding it to the decorated exporter.

### Usage

An example of decorating a `MetricExporter`:

```swift
let metricExporter = ... // create some MetricExporter
let persistenceMetricExporter = try PersistenceMetricExporterDecorator(
  metricExporter: metricExporter,
  storageURL: metricsSubdirectoryURL)
```

An example of decorating a `SpanExporter`:

```swift
let spanExporter = ... // create some SpanExporter
let persistenceTraceExporter = try PersistenceSpanExporterDecorator(
  spanExporter: spanExporter,
  storageURL: tracesSubdirectoryURL)
```
