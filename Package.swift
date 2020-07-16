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
        .library( name: "ZipkinExporter", type: .dynamic, targets: ["ZipkinExporter"]),
        .library( name: "libZipkinExporter", type: .static, targets: ["ZipkinExporter"]),
        .library( name: "StdoutExporter", type: .dynamic, targets: ["StdoutExporter"]),
        .library( name: "libStdoutExporter", type: .static, targets: ["StdoutExporter"]),
        .library( name: "PrometheusExporter", type: .dynamic, targets: ["PrometheusExporter"]),
        .library( name: "libPrometheusExporter", type: .static, targets: ["PrometheusExporter"]),
        .library( name: "OpenTelemetryProtocolExporter", type: .dynamic, targets: ["OpenTelemetryProtocolExporter"]),
        .library( name: "libOpenTelemetryProtocolExporter", type: .static, targets: ["OpenTelemetryProtocolExporter"]),
        .library( name: "InMemoryExporter", type: .dynamic, targets: ["InMemoryExporter"]),
        .library( name: "libInMemoryExporter", type: .static, targets: ["InMemoryExporter"]),
        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    ],
    dependencies: [
        .package(url:  "https://github.com/undefinedlabs/opentracing-objc", .branch("spm-support")), // Need custom fork because of SPM
        .package(url:  "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1"), // Need custom fork because of SPM
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0-alpha.12"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0")
    ],
    targets: [
        .target(  name: "OpenTelemetryApi", dependencies: []),
        .testTarget( name: "OpenTelemetryApiTests", dependencies: ["OpenTelemetryApi"], path: "Tests/OpenTelemetryApiTests"),
        .target(  name: "OpenTelemetrySdk", dependencies: ["OpenTelemetryApi"]),
        .target(  name: "OpenTracingShim", dependencies: ["OpenTelemetrySdk", "libOpentracing"]),
        .testTarget( name: "OpenTracingShimTests", dependencies: ["OpenTracingShim", "OpenTelemetrySdk"], path: "Tests/OpenTracingShim"),
        .testTarget( name: "OpenTelemetrySdkTests", dependencies: ["OpenTelemetryApi", "OpenTelemetrySdk"], path: "Tests/OpenTelemetrySdkTests"),
        .target(  name: "JaegerExporter", dependencies: ["OpenTelemetrySdk", "Thrift"], path: "Sources/Exporters/Jaeger"),
        .testTarget(  name: "JaegerExporterTests", dependencies: ["JaegerExporter"], path: "Tests/ExportersTests/Jaeger"),
        .target(  name: "ZipkinExporter", dependencies: ["OpenTelemetrySdk"], path: "Sources/Exporters/Zipkin"),
        .testTarget(  name: "ZipkinExporterTests", dependencies: ["ZipkinExporter"], path: "Tests/ExportersTests/Zipkin"),
        .target(  name: "StdoutExporter", dependencies: ["OpenTelemetrySdk"], path: "Sources/Exporters/Stdout"),
        .target(  name: "PrometheusExporter", dependencies: ["OpenTelemetrySdk", "NIO", "NIOHTTP1"], path: "Sources/Exporters/Prometheus"),
        .testTarget(  name: "PrometheusExporterTests", dependencies: ["PrometheusExporter"], path: "Tests/ExportersTests/Prometheus"),
        .target(  name: "OpenTelemetryProtocolExporter", dependencies: ["OpenTelemetrySdk", "GRPC"], path: "Sources/Exporters/OpenTelemetryProtocol"),
        .testTarget(  name: "OpenTelemetryProtocolExporterTests", dependencies: ["OpenTelemetryProtocolExporter"], path: "Tests/ExportersTests/OpenTelemetryProtocol"),
        .target( name: "InMemoryExporter", dependencies: ["OpenTelemetrySdk"], path: "Sources/Exporters/InMemory"),
        .testTarget(name: "InMemoryExporterTests", dependencies: ["InMemoryExporter"], path: "Tests/ExportersTests/InMemory"),
        .target(  name: "LoggingTracer", dependencies: ["OpenTelemetryApi"], path: "Examples/Logging Tracer"),
        .target(  name: "SimpleExporter", dependencies: ["OpenTelemetrySdk", "JaegerExporter", "StdoutExporter", "ZipkinExporter"], path: "Examples/Simple Exporter"),
        .target(  name: "PrometheusSample", dependencies: ["OpenTelemetrySdk", "PrometheusExporter"], path: "Examples/Prometheus Sample"),
    ]
)
