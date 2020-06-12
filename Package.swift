// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "opentelemetry-swift",
    platforms: [.macOS(.v10_12),
                .iOS(.v10),
                .tvOS(.v10),
                .watchOS(.v3)],
    products: [
        .library( name: "OpenTelemetryApi", type: .dynamic, targets: ["OpenTelemetryApi"]),
        .library( name: "libOpenTelemetryApi", type: .static, targets: ["OpenTelemetryApi"]),
        .library( name: "OpenTelemetrySdk", type: .dynamic, targets: ["OpenTelemetrySdk"]),
        .library( name: "libOpenTelemetrySdk", type: .static, targets: ["OpenTelemetrySdk"]),
        .library( name: "OpenTracingShim", type: .dynamic, targets: ["OpenTracingShim"]),
        .library( name: "libOpenTracingShim", type: .static, targets: ["OpenTracingShim"]),
        .library( name: "JaegerExporter", type: .dynamic, targets: ["JaegerExporter"]),
        .library( name: "libJaegerExporter", type: .static, targets: ["JaegerExporter"]),
        .library( name: "StdoutExporter", type: .dynamic, targets: ["StdoutExporter"]),
        .library( name: "libStdoutExporter", type: .static, targets: ["StdoutExporter"]),
        .library( name: "PrometheusExporter", type: .dynamic, targets: ["PrometheusExporter"]),
        .library( name: "libPrometheusExporter", type: .static, targets: ["PrometheusExporter"]),

        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    ],
    dependencies: [
        .package(url:  "https://github.com/undefinedlabs/opentracing-objc", .branch("spm-support")), // Need custom fork because of SPM
        .package(url:  "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1"), // Need custom fork because of SPM
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(  name: "OpenTelemetryApi", dependencies: []),
        .testTarget( name: "OpenTelemetryApiTests", dependencies: ["OpenTelemetryApi"], path: "Tests/OpenTelemetryApiTests"),
        .target(  name: "OpenTelemetrySdk", dependencies: ["OpenTelemetryApi"]),
        .target(  name: "OpenTracingShim", dependencies: ["OpenTelemetryApi", "Opentracing"]),
        .testTarget( name: "OpenTelemetrySdkTests", dependencies: ["OpenTelemetryApi", "OpenTelemetrySdk"], path: "Tests/OpenTelemetrySdkTests"),
        .target(  name: "JaegerExporter", dependencies: ["OpenTelemetrySdk", "Thrift"], path: "Sources/Exporters/Jaeger"),
        .testTarget(  name: "JaegerExporterTests", dependencies: ["JaegerExporter"], path: "Tests/ExportersTests/Jaeger"),
        .target(  name: "StdoutExporter", dependencies: ["OpenTelemetrySdk"], path: "Sources/Exporters/Stdout"),
        .target(  name: "PrometheusExporter", dependencies: ["OpenTelemetrySdk", "NIO", "NIOHTTP1"], path: "Sources/Exporters/Prometheus"),
        .testTarget(  name: "PrometheusExporterTests", dependencies: ["PrometheusExporter"], path: "Tests/ExportersTests/Prometheus"),
        .target(  name: "LoggingTracer", dependencies: ["OpenTelemetryApi"], path: "Examples/Logging Tracer"),
        .target(  name: "SimpleExporter", dependencies: ["OpenTelemetrySdk", "JaegerExporter", "StdoutExporter"], path: "Examples/Simple Exporter"),
        .target(  name: "PrometheusSample", dependencies: ["OpenTelemetrySdk", "PrometheusExporter"], path: "Examples/Prometheus Sample"),
    ]
)
