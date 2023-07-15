// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

extension Package {
    func addPlatformSpecific() -> Self {
#if canImport(ObjectiveC)
        self.products.append(contentsOf: [
            .library(name: "OpenTracingShim-experimental", type: .static, targets: ["OpenTracingShim"]),
        ])
        self.targets.append(contentsOf: [
            .target(name: "OpenTracingShim",
                    dependencies: [
                        "OpenTelemetrySdk",
                        .product(name: "Opentracing", package: "opentracing-objc")
                    ],
                    path: "Sources/Importers/OpenTracingShim",
                    exclude: ["README.md"]),
            .testTarget(name: "OpenTracingShimTests",
                        dependencies: ["OpenTracingShim",
                                       "OpenTelemetrySdk",
                                      "OpenTelemetryTestUtils"],
                        path: "Tests/ImportersTests/OpenTracingShim"),
        ])
#endif

#if !os(Linux)
        self.products.append(contentsOf: [
            .library(name: "JaegerExporter", type: .static, targets: ["JaegerExporter"]),
            .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
            .library(name: "NetworkStatus", type: .static, targets: ["NetworkStatus"]),
            .library(name: "URLSessionInstrumentation", type: .static, targets: ["URLSessionInstrumentation"]),
            .library(name: "ZipkinExporter", type: .static, targets: ["ZipkinExporter"]),
            .executable(name: "OTLPExporter", targets: ["OTLPExporter"]),
            .executable(name: "OTLPHTTPExporter", targets: ["OTLPHTTPExporter"]),
            .library(name: "SignPostIntegration", type: .static, targets: ["SignPostIntegration"]),
            .library(name: "ResourceExtension", type: .static, targets: ["ResourceExtension"]),
            .library(name: "DatadogExporter", type: .static, targets: ["DatadogExporter"]),
        ])
        self.targets.append(contentsOf: [
            .target(name: "JaegerExporter",
                    dependencies: [
                        "OpenTelemetrySdk",
                        .product(name: "Thrift", package: "Thrift-Swift", condition: .when(platforms: [.iOS, .macOS, .tvOS, .macCatalyst, .linux]))
                    ],
                    path: "Sources/Exporters/Jaeger"),
            .testTarget(name: "JaegerExporterTests",
                        dependencies: ["JaegerExporter"],
                        path: "Tests/ExportersTests/Jaeger"),
            .executableTarget(
                name: "SimpleExporter",
                dependencies: ["OpenTelemetrySdk", "JaegerExporter", "StdoutExporter", "ZipkinExporter", "ResourceExtension", "SignPostIntegration"],
                path: "Examples/Simple Exporter",
                exclude: ["README.md"]
            ),
            .target(name: "NetworkStatus",
                    dependencies: [
                        "OpenTelemetryApi",
                        .product(name: "Reachability", package: "Reachability.swift", condition: .when(platforms: [.iOS, .macOS, .tvOS, .macCatalyst]))
                    ],
                    path: "Sources/Instrumentation/NetworkStatus",
                    linkerSettings: [.linkedFramework("CoreTelephony", .when(platforms: [.iOS], configuration: nil))]),
            .testTarget(name: "NetworkStatusTests",
                        dependencies: [
                            "NetworkStatus",
                            .product(name: "Reachability", package: "Reachability.swift", condition: .when(platforms: [.iOS, .macOS, .tvOS, .macCatalyst, .linux]))
                        ],
                        path: "Tests/InstrumentationTests/NetworkStatusTests"),
            .target(name: "URLSessionInstrumentation",
                    dependencies: ["OpenTelemetrySdk", "NetworkStatus"],
                    path: "Sources/Instrumentation/URLSession",
                    exclude: ["README.md"]),
            .testTarget(name: "URLSessionInstrumentationTests",
                        dependencies: ["URLSessionInstrumentation",
                                       .product(name: "NIO", package: "swift-nio"),
                                       .product(name: "NIOHTTP1", package: "swift-nio")],
                        path: "Tests/InstrumentationTests/URLSessionTests"),
            .executableTarget(
                name: "NetworkSample",
                dependencies: ["URLSessionInstrumentation", "StdoutExporter"],
                path: "Examples/Network Sample",
                exclude: ["README.md"]
            ),
            .target(name: "ZipkinExporter",
                    dependencies: ["OpenTelemetrySdk"],
                    path: "Sources/Exporters/Zipkin"),
            .testTarget(name: "ZipkinExporterTests",
                        dependencies: ["ZipkinExporter"],
                        path: "Tests/ExportersTests/Zipkin"),
            .executableTarget(
                name: "OTLPExporter",
                dependencies: ["OpenTelemetrySdk", "OpenTelemetryProtocolExporterGrpc", "StdoutExporter", "ZipkinExporter", "ResourceExtension", "SignPostIntegration"],
                path: "Examples/OTLP Exporter",
                exclude: ["README.md"]
            ),
            .executableTarget(
                name: "OTLPHTTPExporter",
                dependencies: ["OpenTelemetrySdk", "OpenTelemetryProtocolExporterHttp", "StdoutExporter", "ZipkinExporter", "ResourceExtension", "SignPostIntegration"],
                path: "Examples/OTLP HTTP Exporter",
                exclude: ["README.md"]
            ),
            .target(name: "SignPostIntegration",
                    dependencies: ["OpenTelemetrySdk"],
                    path: "Sources/Instrumentation/SignPostIntegration",
                    exclude: ["README.md"]),
            .target(name: "ResourceExtension",
                    dependencies: ["OpenTelemetrySdk"],
                    path: "Sources/Instrumentation/SDKResourceExtension",
                    exclude: ["README.md"]),
            .testTarget(name: "ResourceExtensionTests",
                        dependencies: ["ResourceExtension", "OpenTelemetrySdk"],
                        path: "Tests/InstrumentationTests/SDKResourceExtensionTests"),
            .target(name: "DatadogExporter",
                    dependencies: ["OpenTelemetrySdk"],
                    path: "Sources/Exporters/DatadogExporter",
                    exclude: ["NOTICE", "README.md"]),
            .testTarget(name: "DatadogExporterTests",
                        dependencies: ["DatadogExporter",
                                       .product(name: "NIO", package: "swift-nio"),
                                       .product(name: "NIOHTTP1", package: "swift-nio")],
                        path: "Tests/ExportersTests/DatadogExporter"),
            .executableTarget(
                name: "DatadogSample",
                dependencies: ["DatadogExporter"],
                path: "Examples/Datadog Sample",
                exclude: ["README.md"]
            ),
        ])
#endif
        return self
    }
}

let package = Package(
    name: "opentelemetry-swift",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "OpenTelemetryApi", type: .static, targets: ["OpenTelemetryApi"]),
        .library(name: "OpenTelemetrySdk", type: .static, targets: ["OpenTelemetrySdk"]),
        .library(name: "SwiftMetricsShim", type: .static, targets: ["SwiftMetricsShim"]),
        .library(name: "StdoutExporter", type: .static, targets: ["StdoutExporter"]),
        .library(name: "PrometheusExporter", type: .static, targets: ["PrometheusExporter"]),
        .library(name: "OpenTelemetryProtocolExporter", type: .static, targets: ["OpenTelemetryProtocolExporterGrpc"]),
        .library(name: "OpenTelemetryProtocolExporterHTTP", type: .static, targets: ["OpenTelemetryProtocolExporterHttp"]),
        .library(name: "PersistenceExporter", type: .static, targets: ["PersistenceExporter"]),
        .library(name: "InMemoryExporter", type: .static, targets: ["InMemoryExporter"]),
        .executable(name: "loggingTracer", targets: ["LoggingTracer"])
    ],
    dependencies: [
        .package(url: "https://github.com/undefinedlabs/opentracing-objc", from: "0.5.2"),
        .package(url: "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.20.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.4"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.1.1"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-atomics", .upToNextMajor(from: "1.1.0"))
    ],
    targets: [
        .target(name: "OpenTelemetryApi",
                dependencies: [.product(name: "ServiceContextModule", package: "swift-service-context")]),
        .target(name: "OpenTelemetrySdk",
                dependencies: ["OpenTelemetryApi", .product(name: "Atomics", package: "swift-atomics")]),

        .target(name: "SwiftMetricsShim",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "CoreMetrics", package: "swift-metrics")],
                path: "Sources/Importers/SwiftMetricsShim",
                exclude: ["README.md"]),
        .target(name: "PrometheusExporter",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "NIO", package: "swift-nio"),
                               .product(name: "NIOHTTP1", package: "swift-nio")],
                path: "Sources/Exporters/Prometheus"),
        .target(name: "OpenTelemetryProtocolExporterCommon",
                dependencies: ["OpenTelemetrySdk",
                               .product(name: "Logging", package: "swift-log"),
                               .product(name: "SwiftProtobuf", package: "swift-protobuf")],
                path: "Sources/Exporters/OpenTelemetryProtocolCommon"),
        .target(name: "OpenTelemetryProtocolExporterHttp",
                dependencies: ["OpenTelemetrySdk",
                               "OpenTelemetryProtocolExporterCommon"],
                path: "Sources/Exporters/OpenTelemetryProtocolHttp"),
        .target(name: "OpenTelemetryProtocolExporterGrpc",
                dependencies: ["OpenTelemetrySdk",
                               "OpenTelemetryProtocolExporterCommon",
                               .product(name: "GRPC", package: "grpc-swift")],
                path: "Sources/Exporters/OpenTelemetryProtocolGrpc"),
        .target(name: "StdoutExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/Stdout"),
        .target(name: "InMemoryExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/InMemory"),

        .target(name: "PersistenceExporter",
                dependencies: ["OpenTelemetrySdk"],
                path: "Sources/Exporters/Persistence"),
        .target(name: "OpenTelemetryTestUtils",
                dependencies: ["OpenTelemetryApi"]),
        .testTarget(name: "OpenTelemetryApiTests",
                    dependencies: ["OpenTelemetryApi",
                                   "OpenTelemetryTestUtils"],
                    path: "Tests/OpenTelemetryApiTests"),
        .testTarget(name: "OpenTelemetrySdkTests",
                    dependencies: ["OpenTelemetryApi",
                                   "OpenTelemetrySdk",
                                   "OpenTelemetryTestUtils"],
                    path: "Tests/OpenTelemetrySdkTests"),
        .testTarget(name: "SwiftMetricsShimTests",
                    dependencies: ["SwiftMetricsShim",
                                   "OpenTelemetrySdk"],
                    path: "Tests/ImportersTests/SwiftMetricsShim"),
        .testTarget(name: "PrometheusExporterTests",
                    dependencies: ["PrometheusExporter"],
                    path: "Tests/ExportersTests/Prometheus"),
        .testTarget(name: "OpenTelemetryProtocolExporterTests",
                    dependencies: ["OpenTelemetryProtocolExporterGrpc",
                                   "OpenTelemetryProtocolExporterHttp",
                                    .product(name: "NIO", package: "swift-nio"),
                                    .product(name: "NIOHTTP1", package: "swift-nio"),
                                    .product(name: "NIOTestUtils", package: "swift-nio")],
                    path: "Tests/ExportersTests/OpenTelemetryProtocol"),
        .testTarget(name: "InMemoryExporterTests",
                    dependencies: ["InMemoryExporter"],
                    path: "Tests/ExportersTests/InMemory"),

        .testTarget(name: "PersistenceExporterTests",
                    dependencies: ["PersistenceExporter"],
                    path: "Tests/ExportersTests/PersistenceExporter"),
        .executableTarget(
            name: "LoggingTracer",
            dependencies: ["OpenTelemetryApi"],
            path: "Examples/Logging Tracer"
        ),
        .executableTarget(
          name: "LogsSample",
          dependencies: ["OpenTelemetrySdk", "OpenTelemetryProtocolExporterGrpc", .product(name: "GRPC", package: "grpc-swift")],
          path: "Examples/Logs Sample"),
    ]
).addPlatformSpecific()
