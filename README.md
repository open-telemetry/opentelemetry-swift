# opentelemetry-swift

A swift [OpenTelemetry](https://opentelemetry.io/) client

## Installation

This package includes several libraries. The `OpenTelemetryApi` library includes protocols and no-op implementations that comprise the OpenTelemetry API following the [specification](https://github.com/open-telemetry/opentelemetry-specification). The `OpenTelemetrySdk` library is the reference implementation of the API.

Libraries that produce telemetry data should only depend on `OpenTelemetryApi`, and defer the choice of the SDK to the application developer. Applications may depend on `OpenTelemetrySdk` or another package that implements the API.

**Please note** that this library is currently in *alpha*, and shouldn't be used in production environments.

#### Adding the dependency

opentelemetry-swift is designed for Swift 5. To depend on the  opentelemetry-swift package, you need to declare your dependency in your `Package.swift`:

```
.package(url: "https://github.com/undefinedlabs/opentelemetry-swift", from: "0.1.0"),
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

Current code started as an adaptation of the Java OpenTelemetry client (0.2.0), some Swift style still missing in some areas.

Currently Tracing and Correlation Context API's are implemented. 

Implemented also a Jaeger Exporter and a simple stdout exporter

**Missing Metrics API**. Also missing OpenTracing shims and more exporters.

## Examples

The package includes some example projects with basic functionality:

- `Logging Tracer` -  Simple api implementation of a Tracer that logs every api call
- `Simple Exporter` - Shows the Jaeger an Stdout exporters in action using a MultiSpanExporter

