
# opentelemetry-swift

A swift [OpenTelemetry](https://opentelemetry.io/) client

## Installation

This package includes several libraries. The `OpenTelemetryApi` library includes protocols and no-op implementations that comprise the OpenTelemetry API following the [specification](https://github.com/open-telemetry/opentelemetry-specification). The `OpenTelemetrySdk` library is the reference implementation of the API.

Libraries that produce telemetry data should only depend on `OpenTelemetryApi`, and defer the choice of the SDK to the application developer. Applications may depend on `OpenTelemetrySdk` or another package that implements the API.

**Please note** that this library is currently in development, and you should be careful before using in production environments.

#### Adding the dependency

opentelemetry-swift is designed for Swift 5. To depend on the  opentelemetry-swift package, you need to declare your dependency in your `Package.swift`:

```
.package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "0.6.0"),
```

and to your application/library target, add `OpenTelemetryApi` or  `OpenTelemetrySdk`to your `dependencies`, e.g. like this:

```
.target(name: "ExampleTelemetryProducerApp", dependencies: ["OpenTelemetryApi"]),
```

or 

```
.target(name: "ExampleApp", dependencies: ["OpenTelemetrySdk"]),
```

## Current status
**Please note** Tracing spec follows version 1.0.1 and should be considered almost stable now. Metrics support is experimental, and the spec is still under development

Currently Tracing, Metrics and Baggage API's and SDK are implemented, also OpenTracing shims, for compatibility with existing Opentracing code.

Implemented traces exporters: Stdout, Jaeger, Zipkin, Datadog and OpenTelemetry collector

Implemented metrics exporters: Prometheus, Datadog, and OpenTelemetry collector

## Examples

The package includes some example projects with basic functionality:

- `Logging Tracer` -  Simple api implementation of a Tracer that logs every api call
- `Simple Exporter` - Shows the Jaeger an Stdout exporters in action using a MultiSpanExporter. Can be easily modified for other exporters
- `Prometheus Sample` - Shows the Prometheus exporter reporting metrics to a Prometheus instance

