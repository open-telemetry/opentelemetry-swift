// swift-tools-version:6.0
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
    .visionOS(.v1)
  ],
  products: [
    .library(name: "SwiftMetricsShim", targets: ["SwiftMetricsShim"]),
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
    .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    .executable(name: "StableMetricSample", targets: ["StableMetricSample"])
  ],
  dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.3.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.92.0"),
    .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.27.1"),
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.33.3"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.9.1"),
    .package(url: "https://github.com/apple/swift-metrics.git", from: "2.7.1")
  ],
  targets: [
    .target(
      name: "SharedTestUtils",
      dependencies: [],
      path: "Tests/Shared/TestUtils",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .target(
      name: "OTelSwiftLog",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
        .product(name: "Logging", package: "swift-log")
      ],
      path: "Sources/Bridges/OTelSwiftLog",
      exclude: ["README.md"]
    ),
    .target(
      name: "SwiftMetricsShim",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "CoreMetrics", package: "swift-metrics")
      ],
      path: "Sources/Importers/SwiftMetricsShim",
      exclude: ["README.md"]
    ),
    .target(
      name: "PrometheusExporter",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio")
      ],
      path: "Sources/Exporters/Prometheus"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterCommon",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf")
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolCommon"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterHttp",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        "OpenTelemetryProtocolExporterCommon"
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolHttp"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterGrpc",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        "OpenTelemetryProtocolExporterCommon",
        .product(name: "GRPC", package: "grpc-swift")
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolGrpc"
    ),
    .target(
      name: "InMemoryExporter",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Sources/Exporters/InMemory"
    ),
    .target(
      name: "PersistenceExporter",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Sources/Exporters/Persistence",
      exclude: ["README.md"]
    ),
    .target(
      name: "BaggagePropagationProcessor",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")

      ],
      path: "Sources/Contrib/Processors/BaggagePropagationProcessor"
    ),
    .target(
      name: "Sessions",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")

      ],
      path: "Sources/Instrumentation/Sessions",
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "OTelSwiftLogTests",
      dependencies: ["OTelSwiftLog"],
      path: "Tests/BridgesTests/OTelSwiftLog",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "SwiftMetricsShimTests",
      dependencies: [
        "SwiftMetricsShim",
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Tests/ImportersTests/SwiftMetricsShim",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "PrometheusExporterTests",
      dependencies: ["PrometheusExporter"],
      path: "Tests/ExportersTests/Prometheus",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "OpenTelemetryProtocolExporterTests",
      dependencies: [
        "OpenTelemetryProtocolExporterGrpc",
        "OpenTelemetryProtocolExporterHttp",
        "SharedTestUtils",
      ],
      path: "Tests/ExportersTests/OpenTelemetryProtocol",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "InMemoryExporterTests",
      dependencies: ["InMemoryExporter"],
      path: "Tests/ExportersTests/InMemory",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "PersistenceExporterTests",
      dependencies: ["PersistenceExporter"],
      path: "Tests/ExportersTests/PersistenceExporter",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget(
      name: "ContribTests",
      dependencies: [
        "BaggagePropagationProcessor",
        "InMemoryExporter"
      ],
      path: "Tests/ContribTests",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .testTarget( 
      name: "SessionTests",
      dependencies: [
        "Sessions",
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
      ],
      path: "Tests/InstrumentationTests/SessionTests",
      swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
    ),
    .executableTarget(
      name: "LoggingTracer",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
      ],
      path: "Examples/Logging Tracer"
    ),
    .executableTarget(
      name: "LogsSample",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        "OpenTelemetryProtocolExporterGrpc",
        .product(name: "GRPC", package: "grpc-swift")
      ],
      path: "Examples/Logs Sample"
    ),
    .executableTarget(
      name: "StableMetricSample",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        "OpenTelemetryProtocolExporterGrpc",
        .product(name: "StdoutExporter", package: "opentelemetry-swift-core")
      ],
      path: "Examples/Stable Metric Sample",
      exclude: ["README.md"]
    )
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
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(name: "Opentracing", package: "opentracing-objc")
          ],
          path: "Sources/Importers/OpenTracingShim",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "OpenTracingShimTests",
          dependencies: [
            "OpenTracingShim",
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Tests/ImportersTests/OpenTracingShim",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        )
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
        .library(name: "MetricKitInstrumentation", targets: ["MetricKitInstrumentation"])
      ])
      targets.append(contentsOf: [
        .target(
          name: "JaegerExporter",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(
              name: "Thrift", package: "Thrift-Swift",
              condition: .when(platforms: [.iOS, .macOS, .tvOS, .macCatalyst, .linux])
            )
          ],
          path: "Sources/Exporters/Jaeger",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .testTarget(
          name: "JaegerExporterTests",
          dependencies: ["JaegerExporter"],
          path: "Tests/ExportersTests/Jaeger",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .executableTarget(
          name: "SimpleExporter",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
            "JaegerExporter",
            "ZipkinExporter",
            "ResourceExtension", "SignPostIntegration"
          ],
          path: "Examples/Simple Exporter",
          exclude: ["README.md"]
        ),
        .target(
          name: "NetworkStatus",
          dependencies: [
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
          ],
          path: "Sources/Instrumentation/NetworkStatus",
          linkerSettings: [.linkedFramework("CoreTelephony", .when(platforms: [.iOS]))]
        ),
        .testTarget(
          name: "NetworkStatusTests",
          dependencies: [
            "NetworkStatus"
          ],
          path: "Tests/InstrumentationTests/NetworkStatusTests",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .target(
          name: "URLSessionInstrumentation",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            "NetworkStatus"],
          path: "Sources/Instrumentation/URLSession",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "URLSessionInstrumentationTests",
          dependencies: [
            "URLSessionInstrumentation",
            "SharedTestUtils",
          ],
          path: "Tests/InstrumentationTests/URLSessionTests",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .executableTarget(
          name: "NetworkSample",
          dependencies: [
            "URLSessionInstrumentation",
            .product(name: "StdoutExporter", package: "opentelemetry-swift-core")
          ],
          path: "Examples/Network Sample",
          exclude: ["README.md"]
        ),
        .target(
          name: "ZipkinExporter",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Sources/Exporters/Zipkin"
        ),
        .testTarget(
          name: "ZipkinExporterTests",
          dependencies: ["ZipkinExporter"],
          path: "Tests/ExportersTests/Zipkin",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .executableTarget(
          name: "OTLPExporter",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            "OpenTelemetryProtocolExporterGrpc",
            .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
            "ZipkinExporter", "ResourceExtension", "SignPostIntegration"
          ],
          path: "Examples/OTLP Exporter",
          exclude: ["README.md", "prometheus.yaml", "collector-config.yaml", "docker-compose.yaml", "images"]
        ),
        .executableTarget(
          name: "OTLPHTTPExporter",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            "OpenTelemetryProtocolExporterHttp", .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
            "ZipkinExporter", "ResourceExtension", "SignPostIntegration",
          ],
          path: "Examples/OTLP HTTP Exporter",
          exclude: ["README.md", "collector-config.yaml", "docker-compose.yaml", "prometheus.yaml", "images"]
        ),
        .target(
          name: "SignPostIntegration",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Sources/Instrumentation/SignPostIntegration",
          exclude: ["README.md"]
        ),
        .target(
          name: "ResourceExtension",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Sources/Instrumentation/SDKResourceExtension",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "ResourceExtensionTests",
          dependencies: [
            "ResourceExtension",
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Tests/InstrumentationTests/SDKResourceExtensionTests",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .target(
          name: "MetricKitInstrumentation",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Sources/Instrumentation/MetricKit",
          exclude: ["README.md", "StackTraceFormat.md"]
        ),
        .testTarget(
          name: "MetricKitInstrumentationTests",
          dependencies: [
            "MetricKitInstrumentation",
            "InMemoryExporter",
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
          ],
          path: "Tests/InstrumentationTests/MetricKitTests",
          swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking", "-strict-concurrency=minimal"])]
        ),
        .executableTarget(
          name: "PrometheusSample",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            "PrometheusExporter"],
          path: "Examples/Prometheus Sample",
          exclude: ["README.md"]
        )
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