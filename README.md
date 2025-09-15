# <img src="https://opentelemetry.io/img/logos/opentelemetry-logo-nav.png" alt="OpenTelemetry Icon" width="45" height=""> opentelemetry-swift

[![CI](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/BuildAndTest.yml/badge.svg)](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/BuildAndTest.yml?query=branch%3Amain+)
[![codecov](https://codecov.io/gh/open-telemetry/opentelemetry-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/open-telemetry/opentelemetry-swift)

## About

The repository contains the Swift [OpenTelemetry](https://opentelemetry.io/) client

## Getting Started

This package includes several libraries. The `OpenTelemetryApi` library includes protocols and no-op implementations that comprise the OpenTelemetry API following the [specification](https://github.com/open-telemetry/opentelemetry-specification). The `OpenTelemetrySdk` library is the reference implementation of the API.

Libraries that produce telemetry data should only depend on `OpenTelemetryApi`, and defer the choice of the SDK to the application developer. Applications may depend on `OpenTelemetrySdk` or another package that implements the API.

### Adding the dependency

opentelemetry-swift is designed for Swift 5. To depend on the  opentelemetry-swift package, you need to declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.0.0"),
```

and to your application/library target, add `OpenTelemetryApi` or  `OpenTelemetrySdk`to your `dependencies`, e.g. like this:

```swift
.target(name: "ExampleTelemetryProducerApp", dependencies: ["OpenTelemetryApi"]),
```

or

```swift
.target(name: "ExampleApp", dependencies: ["OpenTelemetrySdk"]),
```

### Cocoapods

As of version 1.11.0, OpenTelemetry-Swift support cocoapods. 
Two pods are provided: 

- `OpenTelemetry-Swift-Api`

- `OpenTelemetry-Swift-Sdk`

`OpenTelemetry-Swift-Api` is a dependency of `OpenTelemetry-Swift-Sdk`. 

Most users will want to add the following to their pod file:

`pod 'OpenTelemetry-Swift-Sdk'`

This will add both the API and SDK. If you're only interesting in Adding the API add the following: 

`pod 'OpenTelemetry-Swift-Api'`

## Documentation

Official documentation for the library can be found in the official opentelemetry [documentation  page](https://opentelemetry.io/docs/instrumentation/swift/), including:

* Documentation about installation and [manual instrumentation](https://opentelemetry.io/docs/instrumentation/swift/manual/)

* [Libraries](https://opentelemetry.io/docs/instrumentation/swift/libraries/) that provide automatic instrumentation

## Current status

### API and SDK

Tracing and Baggage are considered stable

Logs are considered beta quality

Metrics is implemented using an outdated spec, is fully functional but will change in the future

### Supported exporters and importers

#### Traces

* Exporters: Stdout, Jaeger, Zipkin, Datadog and OpenTelemetry (OTLP) collector
* Importers: OpenTracingShim

#### Metrics

* Exporters: Prometheus, Datadog, and OpenTelemetry (OTLP) collector
* Importers: SwiftMetricsShim

#### Logs

* Exporters: OpenTelemetry (OTLP) collector

> **_NOTE:_** OTLP exporters are supported both in GRPC and HTTP, only GRPC is production ready, HTTP is still experimental

### Instrumentation libraries

* `URLSession`
* `NetworkStatus`
* `SDKResourceExtension`
* `SignPostIntegration`
* `SessionsEventInstrumentation`

### Third-party exporters
In addition to the specified OpenTelemetry exporters, some third-party exporters have been contributed and can be found in the following repos: 
* [Grafana/faro](https://github.com/grafana/faro-otel-swift-exporter)

## Examples

The package includes some example projects with basic functionality:

* `Datadog Sample` -  Shows the Datadog exporter used with a Simple Exporter, showing how to configure for sending.
* `Logging Tracer` -  Simple api implementation of a Tracer that logs every api call
* `Network Tracer` -  Shows how to use the `URLSessionInstrumentation` instrumentation in your application
* `Simple Exporter` - Shows the Jaeger an Stdout exporters in action using a MultiSpanExporter. Can be easily modified for other exporters
* `Prometheus Sample` - Shows the Prometheus exporter reporting metrics to a Prometheus instance
* `OTLP Exporter` - Shows the OTLP exporter reporting traces to Zipkin and metrics to a Prometheus via the otel-collector

## Contributing
We'd love your help! Use labels [![help wanted](https://img.shields.io/github/issues-search/open-telemetry/opentelemetry-swift?query=is%3Aissue%20is%3Aopen%20label%3A%22help%20wanted%22&label=help%20wanted&color=rgb(0%2C%20134%2C%20114)&logo=opentelemetry)](https://github.com/open-telemetry/opentelemetry-swift/issues?q=state%3Aopen%20label%3A%22help%20wanted%22) and [![good first issue](https://img.shields.io/github/issues-search/open-telemetry/opentelemetry-swift?query=is%3Aissue%20is%3Aopen%20label%3A%22good%20first%20issue%22&label=good%20first%20issue&color=rgb(112%2C%2087%2C%20255)&logo=opentelemetry)](https://github.com/open-telemetry/opentelemetry-swift/issues?q=state%3Aopen%20label%3A%22good%20first%20issue%22) 
 to get started with the project. 
For an overview of how to contribute, see the contributing guide in [CONTRIBUTING.md](CONTRIBUTING.md).

We have a weekly SIG meeting! See the [community page](https://github.com/open-telemetry/community#swift-sdk) for meeting details and notes.

We are also available in the [#otel-swift](https://cloud-native.slack.com/archives/C01NCHR19SB) channel in the [CNCF slack](https://slack.cncf.io/). Please join us there for OTel Swift discussions.

### Maintainers

- [Ariel Demarco](https://github.com/arieldemarco), Embrace
- [Bryce Buchanan](https://github.com/bryce-b), Elastic
- [Ignacio Bonafonte](https://github.com/nachobonafonte), Independent

For more information about the maintainer role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#maintainer).

### Approvers

- [Austin Emmons](https://github.com/atreat), Embrace
- [Vinod Vydier](https://github.com/vvydier), Independent

For more information about the approver role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#approver).

### Triager ([@open-telemetry/swift-triagers](https://github.com/orgs/open-telemetry/teams/swift-triagers))

- [Alolita Sharma](https://github.com/alolita), Apple

For more information about the triager role, see the [community repository](https://github.com/open-telemetry/community/blob/main/community-membership.md#triager).
