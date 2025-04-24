# Faro Exporter

The Faro Exporter is an OpenTelemetry exporter that sends telemetry data to [Grafana Faro](https://grafana.com/oss/faro/), an open-source frontend application monitoring solution. This exporter supports both traces and logs in a single instance with automatic session management, allowing you to monitor your iOS applications using either Grafana Cloud or your own self-hosted infrastructure using [Grafana Alloy](https://grafana.com/docs/alloy) as your collector

## Usage

### Configuration

Create a `FaroExporterOptions` instance with your configuration:

> **Note:** For Grafana Cloud users, you can find your collector URL in the Frontend Observability configuration section of your Grafana Cloud instance. For self-hosted setups using Grafana Alloy, refer to the [Quick Start Guide](https://github.com/grafana/faro-web-sdk/blob/main/docs/sources/tutorials/quick-start-browser.md) for detailed setup instructions.

```swift
let faroOptions = FaroExporterOptions(
    collectorUrl: "http://your-faro-collector.net/collect/YOUR_API_KEY",
    appName: "your-app-name",
    appVersion: "1.0.0",
    appEnvironment: "production"
)
```

### Traces Setup

To use the Faro exporter for traces:

```swift
// Create the Faro exporter
let faroExporter = try! FaroExporter(options: faroOptions)

// Create a span processor with the Faro exporter
let faroProcessor = BatchSpanProcessor(spanExporter: faroExporter)

// Configure the tracer provider
let tracerProvider = TracerProviderBuilder()
    .add(spanProcessor: faroProcessor)
    ...
    .build()
```

### Logs Setup

To use the Faro exporter for logs:

```swift
// Create the Faro exporter (or reuse the one from traces)
let faroExporter = try! FaroExporter(options: faroOptions)

// Create a log processor with the Faro exporter
let faroProcessor = BatchLogRecordProcessor(logRecordExporter: faroExporter)

// Configure the logger provider
let loggerProvider = LoggerProviderBuilder()
    .with(processors: [faroProcessor])
    ...
    .build()
```

## Additional Resources

- [Grafana Faro Documentation](https://grafana.com/oss/faro/)
- [Grafana Alloy Setup Guide](https://grafana.com/docs/alloy/latest/set-up/)
- [Frontend Monitoring Dashboard](https://grafana.com/grafana/dashboards/17766-frontend-monitoring/)
