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
        .library( name: "OpenTelemetrySdk", type: .dynamic, targets: ["OpenTelemetrySdk"]),
        .library( name: "JaegerExporter", type: .dynamic, targets: ["JaegerExporter"]),
        .library( name: "StdoutExporter", type: .dynamic, targets: ["StdoutExporter"]),
        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    ],
    dependencies: [
        .package(url:  "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1") // Need custom fork because of SPM
    ],
    targets: [
        .target(  name: "OpenTelemetryApi", dependencies: []),
        .testTarget( name: "OpenTelemetryApiTests", dependencies: ["OpenTelemetryApi"], path: "Tests/OpenTelemetryApiTests"),
        .target(  name: "OpenTelemetrySdk", dependencies: ["OpenTelemetryApi"]),
        .testTarget( name: "OpenTelemetrySdkTests", dependencies: ["OpenTelemetryApi", "OpenTelemetrySdk"], path: "Tests/OpenTelemetrySdkTests"),
        .target(  name: "JaegerExporter", dependencies: ["OpenTelemetrySdk", "Thrift"], path: "Sources/Exporters/Jaeger"),
        .testTarget(  name: "JaegerExporterTests", dependencies: ["JaegerExporter"], path: "Tests/ExportersTests/Jaeger"),
        .target(  name: "StdoutExporter", dependencies: ["OpenTelemetrySdk"], path: "Sources/Exporters/Stdout"),
        .target(  name: "LoggingTracer", dependencies: ["OpenTelemetryApi"], path: "Examples/Logging Tracer"),
        .target(  name: "SimpleExporter", dependencies: ["OpenTelemetrySdk", "JaegerExporter", "StdoutExporter"], path: "Examples/Simple Exporter"),
    ]
)
