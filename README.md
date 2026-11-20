# <img src="https://opentelemetry.io/img/logos/opentelemetry-logo-nav.png" alt="OpenTelemetry Icon" width="45" height=""> opentelemetry-swift

[![CI](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/BuildAndTest.yml/badge.svg)](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/BuildAndTest.yml?query=branch%3Amain+)
[![Nightly Build](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/Nightly-Build-Core-Main.yml/badge.svg)](https://github.com/open-telemetry/opentelemetry-swift/actions/workflows/Nightly-Build-Core-Main.yml)
[![codecov](https://codecov.io/gh/open-telemetry/opentelemetry-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/open-telemetry/opentelemetry-swift)

## About

The repository contains the Swift [OpenTelemetry](https://opentelemetry.io/) client

## Getting Started

This package includes several libraries. The `OpenTelemetryApi` library includes protocols and no-op implementations that comprise the OpenTelemetry API following the [specification](https://github.com/open-telemetry/opentelemetry-specification). The `OpenTelemetrySdk` library is the reference implementation of the API.

Libraries that produce telemetry data should only depend on `OpenTelemetryApi`, and defer the choice of the SDK to the application developer. Applications may depend on `OpenTelemetrySdk` or another package that implements the API.

### Requirements

The package manifests declare the following requirements. Individual libraries can have additional platform restrictions.

| | Release 2.6.0 | `main` (unreleased) |
| --- | --- | --- |
| Swift tools version | 6.0 | 6.2 |
| iOS | 13 | 15 |
| macOS | 12 | 12 |
| tvOS | 13 | 15 |
| watchOS | 6 | 8 |
| visionOS | 1 | 1 |

See the manifests for [2.6.0](https://github.com/open-telemetry/opentelemetry-swift/blob/2.6.0/Package.swift) and [this branch](Package.swift). Dependencies may require a newer compiler than the manifest's tools version. CI tests the current branch with the toolchains in [BuildAndTest.yml](.github/workflows/BuildAndTest.yml).

### Adding a released version

For release 2.6.0, add these dependencies to your `Package.swift`. The API, SDK and `StdoutExporter` are provided by `opentelemetry-swift-core`; the other exporters and instrumentation are provided by `opentelemetry-swift`.

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "2.6.0"),
.package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.6.0")
```

Add the products your target uses. A library that only produces telemetry needs the API:

```swift
.target(
    name: "ExampleTelemetryProducerApp",
    dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
    ])
```

An application that configures the SDK and exports over OTLP/HTTP can use:

```swift
.target(
    name: "ExampleApp",
    dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift")
    ])
```

### Trying unreleased changes

On `main`, the API and SDK have moved into this repository. Use a single package dependency, and select API/SDK products from `opentelemetry-swift` rather than `opentelemetry-swift-core`. Do not mix this setup with the released core package.

```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", branch: "main")
```

```swift
.target(
    name: "ExampleApp",
    dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift")
    ])
```

Use a [release](https://github.com/open-telemetry/opentelemetry-swift/releases) for applications that need versioned dependencies. `main` is for testing unreleased changes.

### Package traits

Integrations that need a third-party package are behind [package traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md). No trait is enabled by default, so a consumer that enables none resolves and builds only opentelemetry-swift, `swift-protobuf` and `swift-atomics`. Swift 6.2.1 or later leaves the packages of disabled traits out of dependency resolution. Swift 6.2.0 builds correctly but still resolves every package, because of a SwiftPM bug fixed in 6.2.1.

| Trait | Adds | Products |
| --- | --- | --- |
| `OTLPGRPC` (iOS 18 / macOS 15+) | The OTLP exporter over gRPC, built on grpc-swift 2 | `OpenTelemetryProtocolExporter` |
| `OTLPGRPCSwift1` | The deprecated OTLP exporter over gRPC, built on grpc-swift 1, for iOS 15–17 / macOS 12–14. Removed in 4.0. | `OpenTelemetryProtocolExporterGrpcSwift1` |
| `Prometheus` | The Prometheus exporter | `PrometheusExporter` |
| `SwiftObservabilityAPIBridges` | Bridges for the Swift Log, Swift Metrics, and Swift Distributed Tracing APIs | `OTelSwiftLog`, `OTelSwiftTracing`, `SwiftMetricsShim` |
| `Jaeger` | The Jaeger exporter | `JaegerExporter` |
| `OpenTracing` | The experimental OpenTracing shim | `OpenTracingShim-experimental` |
| `CrashReporting` | Crash reporting | `Crash` |

Enable the traits for the products you use in your `Package.swift`:

```swift
.package(
  url: "https://github.com/open-telemetry/opentelemetry-swift.git",
  from: "3.0.0",
  traits: ["OTLPGRPC", "SwiftObservabilityAPIBridges"]
)
```

An Xcode project enables traits on its package dependency instead, as `traits` on the package reference in `project.pbxproj`. Xcode 27.0 reads them from there (see `Examples/HackerNewsDemo`).

#### Migrating from 2.x

Before 3.0.0 every integration was always available. If your build now fails, enable the trait for the module it can't find. Depending on the toolchain, the error reads "no such module" or "unable to resolve module dependency".

| Error | Trait |
| --- | --- |
| no such module `GRPCCore`, `GRPCNIOTransportHTTP2` or `GRPCProtobuf` | `OTLPGRPC` |
| no such module `GRPC` | `OTLPGRPCSwift1` |
| no such module `NIO`, `NIOCore` or `NIOPosix` | `OTLPGRPCSwift1` if you use the grpc-swift 1 exporter, `Prometheus` if you use `PrometheusExporter` |
| no such module `NIOHPACK` | `OTLPGRPCSwift1` |
| no such module `NIOHTTP1` | `Prometheus` |
| no such module `Logging` | `SwiftObservabilityAPIBridges` for `OTelSwiftLog`, `OTLPGRPCSwift1` for the grpc-swift 1 exporter |
| no such module `Tracing` or `CoreMetrics` | `SwiftObservabilityAPIBridges` |
| no such module `Thrift` | `Jaeger` |
| no such module `Opentracing` | `OpenTracing` |
| no such module `KSCrashRecording`, `KSCrashFilters`, `KSCrashDemangleFilter`, `KSCrashInstallations` or `KSCrashReportModel` | `CrashReporting` |

`OpenTelemetryProtocolExporterHTTP` no longer depends on `swift-log`. If you use it and import `Logging` yourself, add `swift-log` to your own dependencies instead of enabling a trait.

If you only import this package's modules, the compiler names the missing trait instead, for example "'JaegerSpanExporter' is unavailable: JaegerExporter requires the `Jaeger` package trait."

#### Migrating the OTLP gRPC exporter to 3.0

With `OTLPGRPC`, `OpenTelemetryProtocolExporter` is built on grpc-swift 2 and needs iOS 18 / macOS 15 or later. `OtlpTraceExporter`, `OtlpMetricExporter` and `OtlpLogExporter` no longer take a grpc-swift 1 `channel:`:

- Pass a `GRPCClient` you run yourself with `client:`, so several exporters can share it. Call `runConnections()` before exporting. Shutting down an exporter doesn't stop the client.
- Or pass a `ClientTransport` with `transport:`. The exporter then owns the client, runs it and stops it on shutdown.
- The `logger:` parameter is removed.
- `OtlpConfiguration.compression` only takes effect when the transport enables the algorithm. Enable gzip in the transport's `compression.enabledAlgorithms`, as in the snippet below.

```swift
// 2.x
let channel = ClientConnection.insecure(group: group).connect(host: "localhost", port: 4317)
let exporter = OtlpTraceExporter(channel: channel)

// 3.0
let transport = try HTTP2ClientTransport.Posix(
  target: .dns(host: "localhost", port: 4317),
  transportSecurity: .plaintext,
  config: .defaults { $0.compression = .init(algorithm: .none, enabledAlgorithms: .gzip) }
)
let exporter = OtlpTraceExporter(transport: transport)
```

To stay on grpc-swift 1, enable `OTLPGRPCSwift1` instead of `OTLPGRPC` and import `OpenTelemetryProtocolExporterGrpcSwift1`. It keeps the `channel:` initializers and is deprecated.

## Documentation

Official documentation for the library can be found in the official opentelemetry [documentation  page](https://opentelemetry.io/docs/instrumentation/swift/), including:

* Documentation about installation and [manual instrumentation](https://opentelemetry.io/docs/instrumentation/swift/manual/)

* [Libraries](https://opentelemetry.io/docs/instrumentation/swift/libraries/) that provide automatic instrumentation

## Current status

### API and SDK

Tracing and Baggage are considered stable

Logs are considered stable. 

Metrics is considered stable.

### Supported exporters and importers

#### Traces

* Exporters: Stdout, Jaeger, Zipkin and OpenTelemetry (OTLP) grpc/http
* Importers: OpenTracingShim

#### Metrics

* Exporters: Prometheus and OpenTelemetry (OTLP) grpc/http
* Importers: SwiftMetricsShim

#### Logs

* Exporters: OpenTelemetry (OTLP) grpc/http


### Instrumentation libraries

Add the products you need to your target and follow their setup instructions; adding a dependency alone does not enable instrumentation.

| Product | Purpose | Availability |
| --- | --- | --- |
| [`URLSessionInstrumentation`](Sources/Instrumentation/URLSession/README.md) | HTTP request spans from `URLSession` | Apple platforms |
| [`NetworkStatus`](Sources/Instrumentation/NetworkStatus) | Network connection attributes | Apple platforms |
| [`ResourceExtension`](Sources/Instrumentation/SDKResourceExtension/README.md) | Application, device, OS and SDK resource attributes | Apple platforms |
| [`SignPostIntegration`](Sources/Instrumentation/SignPostIntegration/README.md) | Connect spans to Apple signposts | Apple platforms; APIs differ by platform |
| [`Sessions`](Sources/Instrumentation/Sessions/README.md) | Session lifecycle events and attribution for spans and logs | Apple platforms and Linux |
| [`MetricKitInstrumentation`](Sources/Instrumentation/MetricKit/README.md) | MetricKit performance and diagnostic payloads | Where MetricKit is available; excludes macOS and tvOS |
| [`Crash`](Sources/Instrumentation/Crash/README.md) | KSCrash crash reporting | Apple platforms; unreleased on `main`, not in 2.6.0 |

The linked documentation follows this branch. For released behavior, use the documentation at your release tag.

### Third-party exporters
In addition to the specified OpenTelemetry exporters, some third-party exporters have been contributed and can be found in the following repos: 
* [Grafana/faro](https://github.com/grafana/faro-otel-swift-exporter)

## Examples

The package includes some example projects with basic functionality:

* `Logging Tracer` -  Simple api implementation of a Tracer that logs every api call
* `Network Sample` - Shows how to use `URLSessionInstrumentation` in your application
* `Simple Exporter` - Shows the Jaeger and Stdout exporters in action using a MultiSpanExporter. Can be easily modified for other exporters
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

- [Vishwan Aranha](https://github.com/aranhave), Grafana Labs
- [Ben Joseph](https://github.com/benjoseph-grafana), Grafana Labs
- [Vinod Vydier](https://github.com/vvydier), Independent
- [Billy Zhou](https://github.com/williazz), Independent

For more information about the approver role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#approver).

### Triager ([@open-telemetry/swift-triagers](https://github.com/orgs/open-telemetry/teams/swift-triagers))

- [Alolita Sharma](https://github.com/alolita), Apple

For more information about the triager role, see the [community repository](https://github.com/open-telemetry/community/blob/main/community-membership.md#triager).

### Emeritus

- [Austin Treat Emmons](https://github.com/atreat), Triager

For more information about the emeritus role, see the
[community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#emeritus-maintainerapprovertriager).
