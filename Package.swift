// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
  name: "opentelemetry-swift",
  platforms: [
    .macOS(.v12),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "OpenTelemetryApi", targets: ["OpenTelemetryApi"]),
    .library(name: "OpenTelemetryConcurrency", targets: ["OpenTelemetryConcurrency"]),
    .library(name: "OpenTelemetrySdk", targets: ["OpenTelemetrySdk"]),
    .library(name: "SwiftMetricsShim", targets: ["SwiftMetricsShim"]),
    .library(name: "StdoutExporter", targets: ["StdoutExporter"]),
    .library(name: "PrometheusExporter", targets: ["PrometheusExporter"]),
    .library(name: "OpenTelemetryProtocolExporter", targets: ["OpenTelemetryProtocolExporterGrpc"]),
    .library(
      name: "OpenTelemetryProtocolExporterHTTP", targets: ["OpenTelemetryProtocolExporterHttp"]
    ),
    .library(name: "PersistenceExporter", targets: ["PersistenceExporter"]),
    .library(name: "InMemoryExporter", targets: ["InMemoryExporter"]),
    .library(name: "OTelSwiftLog", targets: ["OTelSwiftLog"]),
    .library(name: "BaggagePropagationProcessor", targets: ["BaggagePropagationProcessor"]),
    .library(name: "Sessions", targets: ["Sessions"]),
    .executable(name: "ConcurrencyContext", targets: ["ConcurrencyContext"]),
    .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    .executable(name: "StableMetricSample", targets: ["StableMetricSample"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.83.0"),
    .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.26.1"),
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.30.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
    .package(url: "https://github.com/apple/swift-metrics.git", from: "2.7.0"),
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0"),
    .package(url: "https://github.com/mw99/DataCompression", from: "3.9.0"),
  ],
  targets: [
    .target(
      name: "OpenTelemetryApi",
      dependencies: []
    ),
    .target(
      name: "OpenTelemetrySdk",
      dependencies: [
        "OpenTelemetryApi",
        .product(name: "Atomics", package: "swift-atomics", condition: .when(platforms: [.linux])),
      ]
    ),
    .target(
      name: "OpenTelemetryConcurrency",
      dependencies: ["OpenTelemetryApi"]
    ),
    .target(
      name: "OpenTelemetryTestUtils",
      dependencies: ["OpenTelemetryApi", "OpenTelemetrySdk"]
    ),
    .target(
      name: "OTelSwiftLog",
      dependencies: [
        "OpenTelemetryApi",
        .product(name: "Logging", package: "swift-log"),
      ],
      path: "Sources/Bridges/OTelSwiftLog",
      exclude: ["README.md"]
    ),
    .target(
      name: "SwiftMetricsShim",
      dependencies: [
        "OpenTelemetrySdk",
        .product(name: "CoreMetrics", package: "swift-metrics"),
      ],
      path: "Sources/Importers/SwiftMetricsShim",
      exclude: ["README.md"]
    ),
    .target(
      name: "PrometheusExporter",
      dependencies: [
        "OpenTelemetrySdk",
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
      ],
      path: "Sources/Exporters/Prometheus"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterCommon",
      dependencies: [
        "OpenTelemetrySdk",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolCommon"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterHttp",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterCommon",
        .product(
          name: "DataCompression",
          package: "DataCompression",
          condition: .when(platforms: [.macOS, .iOS, .watchOS, .tvOS, .visionOS])
        ),
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolHttp"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterGrpc",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterCommon",
        .product(name: "GRPC", package: "grpc-swift"),
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolGrpc"
    ),
    .target(
      name: "StdoutExporter",
      dependencies: ["OpenTelemetrySdk"],
      path: "Sources/Exporters/Stdout"
    ),
    .target(
      name: "InMemoryExporter",
      dependencies: ["OpenTelemetrySdk"],
      path: "Sources/Exporters/InMemory"
    ),
    .target(
      name: "PersistenceExporter",
      dependencies: ["OpenTelemetrySdk"],
      path: "Sources/Exporters/Persistence",
      exclude: ["README.md"]
    ),
    .target(
      name: "BaggagePropagationProcessor",
      dependencies: [
        "OpenTelemetryApi",
        "OpenTelemetrySdk",
      ],
      path: "Sources/Contrib/Processors/BaggagePropagationProcessor"
    ),
    .target(
      name: "Sessions",
      dependencies: [
        "OpenTelemetryApi",
        "OpenTelemetrySdk",
      ],
      path: "Sources/Instrumentation/Sessions",
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "OTelSwiftLogTests",
      dependencies: ["OTelSwiftLog"],
      path: "Tests/BridgesTests/OTelSwiftLog"
    ),
    .testTarget(
      name: "OpenTelemetryApiTests",
      dependencies: ["OpenTelemetryApi", "OpenTelemetryTestUtils"],
      path: "Tests/OpenTelemetryApiTests"
    ),
    .testTarget(
      name: "OpenTelemetrySdkTests",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryConcurrency",
        "OpenTelemetryTestUtils",
      ],
      path: "Tests/OpenTelemetrySdkTests"
    ),
    .testTarget(
      name: "SwiftMetricsShimTests",
      dependencies: [
        "SwiftMetricsShim",
        "OpenTelemetrySdk",
      ],
      path: "Tests/ImportersTests/SwiftMetricsShim"
    ),
    .testTarget(
      name: "PrometheusExporterTests",
      dependencies: ["PrometheusExporter"],
      path: "Tests/ExportersTests/Prometheus"
    ),
    .testTarget(
      name: "OpenTelemetryProtocolExporterTests",
      dependencies: [
        "OpenTelemetryProtocolExporterGrpc",
        "OpenTelemetryProtocolExporterHttp",
        .product(
          name: "DataCompression",
          package: "DataCompression",
          condition: .when(platforms: [.macOS, .iOS, .watchOS, .tvOS, .visionOS])
        ),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOTestUtils", package: "swift-nio"),
      ],
      path: "Tests/ExportersTests/OpenTelemetryProtocol"
    ),
    .testTarget(
      name: "InMemoryExporterTests",
      dependencies: ["InMemoryExporter"],
      path: "Tests/ExportersTests/InMemory"
    ),
    .testTarget(
      name: "PersistenceExporterTests",
      dependencies: ["PersistenceExporter"],
      path: "Tests/ExportersTests/PersistenceExporter"
    ),
    .testTarget(
      name: "ContribTests",
      dependencies: [
        "BaggagePropagationProcessor",
        "InMemoryExporter",
      ]
    ),
    .testTarget(
      name: "SessionTests",
      dependencies: [
        "Sessions",
        "OpenTelemetrySdk",
        "OpenTelemetryTestUtils",
      ],
      path: "Tests/InstrumentationTests/SessionTests"
    ),
    .executableTarget(
      name: "LoggingTracer",
      dependencies: ["OpenTelemetryApi"],
      path: "Examples/Logging Tracer"
    ),
    .executableTarget(
      name: "LogsSample",
      dependencies: [
        "OpenTelemetrySdk", "OpenTelemetryProtocolExporterGrpc",
        .product(name: "GRPC", package: "grpc-swift"),
      ],
      path: "Examples/Logs Sample"
    ),
    .executableTarget(
      name: "ConcurrencyContext",
      dependencies: ["OpenTelemetrySdk", "OpenTelemetryConcurrency", "StdoutExporter"],
      path: "Examples/ConcurrencyContext"
    ),
    .executableTarget(
      name: "StableMetricSample",
      dependencies: ["OpenTelemetrySdk", "OpenTelemetryProtocolExporterGrpc", "StdoutExporter"],
      path: "Examples/Stable Metric Sample",
      exclude: ["README.md"]
    ),
  ]
).addPlatformSpecific()

extension Package {
  func addPlatformSpecific() -> Self {
    #if canImport(ObjectiveC)
      dependencies.append(
        .package(url: "https://github.com/undefinedlabs/opentracing-objc", from: "0.5.2")
      )
      products.append(
        .library(name: "OpenTracingShim-experimental", targets: ["OpenTracingShim"])
      )
      targets.append(contentsOf: [
        .target(
          name: "OpenTracingShim",
          dependencies: [
            "OpenTelemetrySdk",
            .product(name: "Opentracing", package: "opentracing-objc"),
          ],
          path: "Sources/Importers/OpenTracingShim",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "OpenTracingShimTests",
          dependencies: [
            "OpenTracingShim",
            "OpenTelemetrySdk",
          ],
          path: "Tests/ImportersTests/OpenTracingShim"
        ),
      ])
    #endif

    #if canImport(Darwin)
      dependencies.append(
        .package(url: "https://github.com/undefinedlabs/Thrift-Swift", from: "1.1.1")
      )
      products.append(contentsOf: [
        .library(name: "JaegerExporter", targets: ["JaegerExporter"]),
        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .library(name: "NetworkStatus", targets: ["NetworkStatus"]),
        .library(name: "URLSessionInstrumentation", targets: ["URLSessionInstrumentation"]),
        .library(name: "ZipkinExporter", targets: ["ZipkinExporter"]),
        .executable(name: "OTLPExporter", targets: ["OTLPExporter"]),
        .executable(name: "OTLPHTTPExporter", targets: ["OTLPHTTPExporter"]),
        .library(name: "SignPostIntegration", targets: ["SignPostIntegration"]),
        .library(name: "ResourceExtension", targets: ["ResourceExtension"]),
      ])
      targets.append(contentsOf: [
        .target(
          name: "JaegerExporter",
          dependencies: [
            "OpenTelemetrySdk",
            .product(
              name: "Thrift", package: "Thrift-Swift",
              condition: .when(platforms: [.iOS, .macOS, .tvOS, .macCatalyst, .linux])
            ),
          ],
          path: "Sources/Exporters/Jaeger"
        ),
        .testTarget(
          name: "JaegerExporterTests",
          dependencies: ["JaegerExporter"],
          path: "Tests/ExportersTests/Jaeger"
        ),
        .executableTarget(
          name: "SimpleExporter",
          dependencies: [
            "OpenTelemetrySdk", "JaegerExporter", "StdoutExporter", "ZipkinExporter",
            "ResourceExtension", "SignPostIntegration",
          ],
          path: "Examples/Simple Exporter",
          exclude: ["README.md"]
        ),
        .target(
          name: "NetworkStatus",
          dependencies: [
            "OpenTelemetryApi"
          ],
          path: "Sources/Instrumentation/NetworkStatus",
          linkerSettings: [.linkedFramework("CoreTelephony", .when(platforms: [.iOS]))]
        ),
        .testTarget(
          name: "NetworkStatusTests",
          dependencies: [
            "NetworkStatus"
          ],
          path: "Tests/InstrumentationTests/NetworkStatusTests"
        ),
        .target(
          name: "URLSessionInstrumentation",
          dependencies: ["OpenTelemetrySdk", "NetworkStatus"],
          path: "Sources/Instrumentation/URLSession",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "URLSessionInstrumentationTests",
          dependencies: [
            "URLSessionInstrumentation",
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
          ],
          path: "Tests/InstrumentationTests/URLSessionTests"
        ),
        .executableTarget(
          name: "NetworkSample",
          dependencies: ["URLSessionInstrumentation", "StdoutExporter"],
          path: "Examples/Network Sample",
          exclude: ["README.md"]
        ),
        .target(
          name: "ZipkinExporter",
          dependencies: ["OpenTelemetrySdk"],
          path: "Sources/Exporters/Zipkin"
        ),
        .testTarget(
          name: "ZipkinExporterTests",
          dependencies: ["ZipkinExporter"],
          path: "Tests/ExportersTests/Zipkin"
        ),
        .executableTarget(
          name: "OTLPExporter",
          dependencies: [
            "OpenTelemetrySdk", "OpenTelemetryProtocolExporterGrpc", "StdoutExporter",
            "ZipkinExporter", "ResourceExtension", "SignPostIntegration",
          ],
          path: "Examples/OTLP Exporter",
          exclude: ["README.md", "prometheus.yaml", "collector-config.yaml", "docker-compose.yaml", "images"]
        ),
        .executableTarget(
          name: "OTLPHTTPExporter",
          dependencies: [
            "OpenTelemetrySdk", "OpenTelemetryProtocolExporterHttp", "StdoutExporter",
            "ZipkinExporter", "ResourceExtension", "SignPostIntegration",
            .product(
              name: "DataCompression",
              package: "DataCompression",
              condition: .when(platforms: [.macOS, .iOS, .watchOS, .tvOS, .visionOS])
            ),
          ],
          path: "Examples/OTLP HTTP Exporter",
          exclude: ["README.md", "collector-config.yaml", "docker-compose.yaml", "prometheus.yaml", "images"]
        ),
        .target(
          name: "SignPostIntegration",
          dependencies: ["OpenTelemetrySdk"],
          path: "Sources/Instrumentation/SignPostIntegration",
          exclude: ["README.md"]
        ),
        .target(
          name: "ResourceExtension",
          dependencies: ["OpenTelemetrySdk"],
          path: "Sources/Instrumentation/SDKResourceExtension",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "ResourceExtensionTests",
          dependencies: ["ResourceExtension", "OpenTelemetrySdk"],
          path: "Tests/InstrumentationTests/SDKResourceExtensionTests"
        ),
        .executableTarget(
          name: "PrometheusSample",
          dependencies: ["OpenTelemetrySdk", "PrometheusExporter"],
          path: "Examples/Prometheus Sample",
          exclude: ["README.md"]
        ),
      ])
    #endif

    return self
  }
}

if ProcessInfo.processInfo.environment["OTEL_ENABLE_SWIFTLINT"] != nil {
  package.dependencies.append(contentsOf: [
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.57.1")
  ])

  for target in package.targets {
    target.plugins = [
      .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
    ]
  }
}
