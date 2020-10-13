# Datadog OpenTelemetry exporter

The OpenTelemetry Datadog Exporter provides a span exporter from OpenTelemetry traces to Datadog using the http endpoints (not using the datadog agent)

It will convert Opentelemetry spans to Datadog traces and span Events to Datadog logs. There is still no support for metrics

It is currently only using the endpoints for mobile applications and Client tokens, will be expanded in the future.

## Getting Started

*This is a work in progress, and currently in an alpha stage, should not be used in production.*

### Usage

The Datadog exporter provides a SpanExporter that must be added to an active SpanProcessor:

 Initialize the DatadogExporter with the settings you want for reporting:

```swift
let exporterConfiguration = ExporterConfiguration(
    serviceName: "Otel exporter Example",
    resource: "OTel exporter",
    applicationName: "SimpleExample",
    applicationVersion: "0.0.1",
    environment: "test",
    clientToken: clientToken,
    endpoint: Endpoint.us,
    uploadCondition: { true }
)
let datadogExporter = try! DatadogExporter(config: exporterConfiguration)
```
Add this exporter to a SpanProcessor that is active in the tracer

```swift
var spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)
```






