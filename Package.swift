// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "opentelemetry-swift",
    platforms: [.macOS(.v10_13),
                .iOS(.v11),
                .tvOS(.v11),
                .watchOS(.v3)],
    products: [
        .library(name: "OpenTelemetryApi", type: .dynamic, targets: ["OpenTelemetryApi"]),
        .library(name: "libOpenTelemetryApi", type: .static, targets: ["OpenTelemetryApi"]),
        .library(name: "OpenTelemetrySdk", type: .dynamic, targets: ["OpenTelemetrySdk"]),
        .library(name: "libOpenTelemetrySdk", type: .static, targets: ["OpenTelemetrySdk"]),
        .library(name: "OpenTracingShim", type: .dynamic, targets: ["OpenTracingShim"]),
        .library(name: "libOpenTracingShim", type: .static, targets: ["OpenTracingShim"]),
        .library(name: "JaegerExporter", type: .dynamic, targets: ["JaegerExporter"]),
        .library(name: "libJaegerExporter", type: .static, targets: ["JaegerExporter"]),
        .library(name: "ZipkinExporter", type: .dynamic, targets: ["ZipkinExporter"]),
        .library(name: "libZipkinExporter", type: .static, targets: ["ZipkinExporter"]),
        .library(name: "StdoutExporter", type: .dynamic, targets: ["StdoutExporter"]),
        .library(name: "libStdoutExporter", type: .static, targets: ["StdoutExporter"]),
        .library(name: "PrometheusExporter", type: .dynamic, targets: ["PrometheusExporter"]),
        .library(name: "libPrometheusExporter", type: .static, targets: ["PrometheusExporter"]),
        .library(name: "OpenTelemetryProtocolExporter", type: .dynamic, targets: ["OpenTelemetryProtocolExporter"]),
        .library(name: "libOpenTelemetryProtocolExporter", type: .static, targets: ["OpenTelemetryProtocolExporter"]),
        .library(name: "InMemoryExporter", type: .dynamic, targets: ["InMemoryExporter"]),
        .library(name: "libInMemoryExporter", type: .static, targets: ["InMemoryExporter"]),
        .library(name: "DatadogExporter", type: .dynamic, targets: ["DatadogExporter"]),
        .library(name: "libDatadogExporter", type: .static, targets: ["DatadogExporter"]),
        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    ],
    dependencies: [
        .package(name: "Opentracing", url: "https://github.com/undefinedlabs/opentracing-objc", from: "0.5.2"),
        .package(name: "Thrift", url: "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1"),
        .package(name: "swift-nio", url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(name: "grpc-swift", url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0-alpha.12"),
        .package(name: "SwiftProtobuf", url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0")
    ],
    targets: [
        .target(name: "OpenTelemetryApi",
                dependencies: []
        ),
        .target(name: "OpenTelemetrySdk",
                dependencies: ["OpenTelemetryApi"]
        ),
        .target(name: "OpenTracingShim",
                dependencies: ["OpenTelemetrySdk",
                               "Opentracing"]
        ),
        .target(name: "JaegerExporter",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "Thrift", package: "Thrift")],
                path: "Sources/Exporters/Jaeger"
        ),
        .target(name: "ZipkinExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/Zipkin"
        ),
        .target(name: "PrometheusExporter",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "NIO", package: "swift-nio"),
                               .product(name: "NIOHTTP1", package: "swift-nio")],
                path: "Sources/Exporters/Prometheus"
        ),
        .target(name: "OpenTelemetryProtocolExporter",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "GRPC", package: "grpc-swift")],
                path: "Sources/Exporters/OpenTelemetryProtocol"
        ),
        .target(name: "StdoutExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/Stdout"
        ),
        .target(name: "InMemoryExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/InMemory"
        ),
        .target(name: "DatadogExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/DatadogExporter"
        ),
        .testTarget(name: "OpenTelemetryApiTests",
                    dependencies: ["OpenTelemetryApi"],
                    path: "Tests/OpenTelemetryApiTests"
        ),
        .testTarget(name: "OpenTracingShimTests",
                    dependencies: ["OpenTracingShim",
                                   "OpenTelemetrySdk"],
                    path: "Tests/OpenTracingShim"
        ),
        .testTarget(name: "OpenTelemetrySdkTests",
                    dependencies: ["OpenTelemetryApi",
                                   "OpenTelemetrySdk"],
                    path: "Tests/OpenTelemetrySdkTests"
        ),
        .testTarget(name: "JaegerExporterTests",
                    dependencies: ["JaegerExporter"],
                    path: "Tests/ExportersTests/Jaeger"
        ),
        .testTarget(name: "ZipkinExporterTests",
                    dependencies: ["ZipkinExporter"],
                    path: "Tests/ExportersTests/Zipkin"
        ),
        .testTarget(name: "PrometheusExporterTests",
                    dependencies: ["PrometheusExporter"],
                    path: "Tests/ExportersTests/Prometheus"
        ),
        .testTarget(name: "OpenTelemetryProtocolExporterTests",
                    dependencies: ["OpenTelemetryProtocolExporter"],
                    path: "Tests/ExportersTests/OpenTelemetryProtocol"
        ),
        .testTarget(name: "InMemoryExporterTests",
                    dependencies: ["InMemoryExporter"],
                    path: "Tests/ExportersTests/InMemory"
        ),
        .testTarget(name: "DatadogExporterTests",
                    dependencies: ["DatadogExporter",
                                   .product(name: "NIO", package: "swift-nio"),
                                   .product(name: "NIOHTTP1", package: "swift-nio")],
                    path: "Tests/ExportersTests/DatadogExporter"
        ),
        .target(name: "LoggingTracer",
                dependencies: ["OpenTelemetryApi"],
                path: "Examples/Logging Tracer"
        ),
        .target(name: "SimpleExporter",
                dependencies: ["OpenTelemetrySdk", "JaegerExporter", "StdoutExporter", "ZipkinExporter"],
                path: "Examples/Simple Exporter"
        ),
        .target(name: "PrometheusSample",
                dependencies: ["OpenTelemetrySdk", "PrometheusExporter"],
                path: "Examples/Prometheus Sample"
        ),
        .target(name: "DatadogSample",
                dependencies: ["DatadogExporter"],
                path: "Examples/Datadog Sample"
        ),
    ]
)
