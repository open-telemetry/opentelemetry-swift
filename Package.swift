// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

enum PackageTraitName {
  static let otlpGRPC = "OTLPGRPC"
  static let prometheus = "Prometheus"
  static let swiftObservabilityAPIBridges = "SwiftObservabilityAPIBridges"
  static let jaeger = "Jaeger"
  static let openTracing = "OpenTracing"
  static let crashReporting = "CrashReporting"
}

let packageTraits: [Trait] = [
  .trait(
    name: PackageTraitName.otlpGRPC,
    description: "Adds the OTLP exporter over gRPC."
  ),
  .trait(
    name: PackageTraitName.prometheus,
    description: "Adds the Prometheus exporter."
  ),
  .trait(
    name: PackageTraitName.swiftObservabilityAPIBridges,
    description: "Adds bridges for the Swift Log, Swift Metrics, and Swift Distributed Tracing APIs."
  ),
  .trait(
    name: PackageTraitName.jaeger,
    description: "Adds the Jaeger exporter."
  ),
  .trait(
    name: PackageTraitName.openTracing,
    description: "Adds the experimental OpenTracing shim."
  ),
  .trait(
    name: PackageTraitName.crashReporting,
    description: "Adds crash reporting."
  ),
]

// xcodebuild can't pass trait flags, so CI's simulator jobs enable every trait through this variable.
let enableAllTraits = ProcessInfo.processInfo.environment["OTEL_SWIFT_ENABLE_ALL_TRAITS"] != nil

extension TargetDependencyCondition {
  // Swift 6.2.0 resolves trait conditions incorrectly (swiftlang/swift-package-manager#9141),
  // so it ignores the trait there but keeps any platform restriction.
  static func whenTrait(_ trait: String, platforms: [Platform]? = nil) -> TargetDependencyCondition? {
    #if compiler(>=6.2.0) && compiler(<6.2.1)
      return platforms.flatMap { .when(platforms: $0) }
    #else
      if let platforms { return .when(platforms: platforms, traits: [trait]) }
      return .when(traits: [trait])
    #endif
  }
}

let package = Package(
  name: "opentelemetry-swift",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "OpenTelemetryApi", targets: ["OpenTelemetryApi"]),
    .library(
      name: "OpenTelemetryConcurrency",
      targets: ["OpenTelemetryConcurrency"]
    ),
    .library(name: "OpenTelemetrySdk", targets: ["OpenTelemetrySdk"]),
    .library(name: "StdoutExporter", targets: ["StdoutExporter"]),
    .library(name: "SwiftMetricsShim", targets: ["SwiftMetricsShim"]),
    .library(name: "PrometheusExporter", targets: ["PrometheusExporter"]),
    .library(
      name: "OpenTelemetryProtocolExporter",
      targets: ["OpenTelemetryProtocolExporterGrpc"]
    ),
    .library(
      name: "OpenTelemetryProtocolExporterHTTP",
      targets: ["OpenTelemetryProtocolExporterHttp"]
    ),
    .library(name: "PersistenceExporter", targets: ["PersistenceExporter"]),
    .library(name: "InMemoryExporter", targets: ["InMemoryExporter"]),
    .library(name: "OTelSwiftLog", targets: ["OTelSwiftLog"]),
    .library(name: "OTelSwiftTracing", targets: ["OTelSwiftTracing"]),
    .library(
      name: "BaggagePropagationProcessor",
      targets: ["BaggagePropagationProcessor"]
    ),
    .library(name: "Sessions", targets: ["Sessions"]),
    .executable(name: "ConcurrencyContext", targets: ["ConcurrencyContext"]),
    .executable(name: "loggingTracer", targets: ["LoggingTracer"]),
    .executable(name: "StableMetricSample", targets: ["StableMetricSample"]),
  ],
  traits: Set(packageTraits + [.default(enabledTraits: enableAllTraits ? Set(packageTraits.map(\.name)) : [])]),
  dependencies: [
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.1"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.104.0"),
    .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.27.6"),
    .package(
      url: "https://github.com/apple/swift-protobuf.git",
      from: "1.39.0"
    ),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.16.2"),
    .package(url: "https://github.com/apple/swift-metrics.git", from: "2.13.0"),
    .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.7.3")
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
        .product(
          name: "Atomics",
          package: "swift-atomics",
          condition: .when(platforms: [.linux])
        ),
      ]
    ),
    .target(
      name: "OpenTelemetryConcurrency",
      dependencies: ["OpenTelemetryApi"]
    ),
    .target(
      name: "StdoutExporter",
      dependencies: ["OpenTelemetrySdk"],
      path: "Sources/Exporters/Stdout"
    ),
    .target(
      name: "OTelSwiftLog",
      dependencies: [
        "OpenTelemetryApi",
        .product(
          name: "Logging",
          package: "swift-log",
          condition: .whenTrait(PackageTraitName.swiftObservabilityAPIBridges)
        ),
      ],
      path: "Sources/Bridges/OTelSwiftLog",
      exclude: ["README.md"]
    ),
    .target(
      name: "OTelSwiftTracing",
      dependencies: [
        "OpenTelemetryApi",
        .product(
          name: "Tracing",
          package: "swift-distributed-tracing",
          condition: .whenTrait(PackageTraitName.swiftObservabilityAPIBridges)
        ),
      ],
      path: "Sources/Bridges/OTelSwiftTracing",
      exclude: ["README.md"]
    ),
    .target(
      name: "SwiftMetricsShim",
      dependencies: [
        "OpenTelemetrySdk",
        .product(
          name: "CoreMetrics",
          package: "swift-metrics",
          condition: .whenTrait(PackageTraitName.swiftObservabilityAPIBridges)
        ),
      ],
      path: "Sources/Importers/SwiftMetricsShim",
      exclude: ["README.md"]
    ),
    .target(
      name: "PrometheusExporter",
      dependencies: [
        "OpenTelemetrySdk",
        .product(
          name: "NIO",
          package: "swift-nio",
          condition: .whenTrait(PackageTraitName.prometheus)
        ),
        .product(
          name: "NIOHTTP1",
          package: "swift-nio",
          condition: .whenTrait(PackageTraitName.prometheus)
        ),
      ],
      path: "Sources/Exporters/Prometheus"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterCommon",
      dependencies: [
        "OpenTelemetrySdk",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolCommon"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterHttp",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterCommon",
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolHttp"
    ),
    .target(
      name: "OpenTelemetryProtocolExporterGrpc",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterCommon",
        .product(
          name: "GRPC",
          package: "grpc-swift",
          condition: .whenTrait(PackageTraitName.otlpGRPC)
        ),
        .product(
          name: "Logging",
          package: "swift-log",
          condition: .whenTrait(PackageTraitName.otlpGRPC)
        ),
      ],
      path: "Sources/Exporters/OpenTelemetryProtocolGrpc"
    ),
    .target(
      name: "InMemoryExporter",
      dependencies: [
        "OpenTelemetrySdk"
      ],
      path: "Sources/Exporters/InMemory"
    ),
    .target(
      name: "PersistenceExporter",
      dependencies: [
        "OpenTelemetrySdk"
      ],
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
    .target(
      name: "SharedTestUtils",
      dependencies: [
        "OpenTelemetryApi",
        "OpenTelemetrySdk",
      ]
    ),
    .testTarget(
      name: "OpenTelemetryApiTests",
      dependencies: ["OpenTelemetryApi", "SharedTestUtils"],
      path: "Tests/OpenTelemetryApiTests",
      swiftSettings: [
        .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
      ]
    ),
    .testTarget(
      name: "OpenTelemetrySdkTests",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryConcurrency",
        "SharedTestUtils",
      ],
      path: "Tests/OpenTelemetrySdkTests",
      swiftSettings: [
        .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
      ]
    ),

    .testTarget(
      name: "OTelSwiftLogTests",
      dependencies: [
        "SharedTestUtils",
        "OTelSwiftLog",
        "OpenTelemetrySdk",
      ],
      path: "Tests/BridgesTests/OTelSwiftLog"
    ),
    .testTarget(
      name: "SharedTestUtilsTests",
      dependencies: ["SharedTestUtils"],
      path: "Tests/SharedTestUtilsTests"
    ),
    .testTarget(
      name: "OTelSwiftTracingTests",
      dependencies: [
        "SharedTestUtils",
        "OTelSwiftTracing",
        "InMemoryExporter",
        "OpenTelemetrySdk",
      ],
      path: "Tests/BridgesTests/OTelSwiftTracing"
    ),
    .testTarget(
      name: "SwiftMetricsShimTests",
      dependencies: [
        "SharedTestUtils",
        "SwiftMetricsShim",
        "OpenTelemetrySdk",
      ],
      path: "Tests/ImportersTests/SwiftMetricsShim"
    ),
    .testTarget(
      name: "PrometheusExporterTests",
      dependencies: [
        "PrometheusExporter",
        "SharedTestUtils",
      ],
      path: "Tests/ExportersTests/Prometheus"
    ),
    .testTarget(
      name: "OpenTelemetryProtocolExporterTests",
      dependencies: [
        "OpenTelemetryProtocolExporterGrpc",
        "OpenTelemetryProtocolExporterHttp",
        "SharedTestUtils",
      ],
      path: "Tests/ExportersTests/OpenTelemetryProtocol"
    ),
    .testTarget(
      name: "InMemoryExporterTests",
      dependencies: [
        "InMemoryExporter",
        "SharedTestUtils",
      ],
      path: "Tests/ExportersTests/InMemory"
    ),
    .testTarget(
      name: "PersistenceExporterTests",
      dependencies: [
        "SharedTestUtils",
        "PersistenceExporter",
        "OpenTelemetryProtocolExporterHttp",
        "InMemoryExporter",
      ],
      path: "Tests/ExportersTests/PersistenceExporter"
    ),
    .testTarget(
      name: "ContribTests",
      dependencies: [
        "SharedTestUtils",
        "BaggagePropagationProcessor",
        "InMemoryExporter",
      ]
    ),
    .testTarget(
      name: "SessionTests",
      dependencies: [
        "SharedTestUtils",
        "Sessions",
        "OpenTelemetrySdk",
      ],
      path: "Tests/InstrumentationTests/SessionTests"
    ),
    .executableTarget(
      name: "ConcurrencyContext",
      dependencies: [
        "OpenTelemetrySdk", "OpenTelemetryConcurrency", "StdoutExporter",
      ],
      path: "Examples/ConcurrencyContext"
    ),
    .executableTarget(
      name: "LoggingTracer",
      dependencies: [
        "OpenTelemetryApi"
      ],
      path: "Examples/Logging Tracer"
    ),
    .executableTarget(
      name: "LogsSample",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterGrpc",
        .product(
          name: "GRPC",
          package: "grpc-swift",
          condition: .whenTrait(PackageTraitName.otlpGRPC)
        ),
      ],
      path: "Examples/Logs Sample"
    ),
    .executableTarget(
      name: "StableMetricSample",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryProtocolExporterGrpc",
        "StdoutExporter",
      ],
      path: "Examples/Stable Metric Sample",
      exclude: ["README.md"]
    ),
  ]
).addPlatformSpecific()

extension Package {
  func addPlatformSpecific() -> Self {
    #if canImport(ObjectiveC)
      dependencies.append(
        .package(
          url: "https://github.com/undefinedlabs/opentracing-objc",
          from: "0.5.2"
        )
      )
      products.append(
        .library(
          name: "OpenTracingShim-experimental",
          targets: ["OpenTracingShim"]
        )
      )
      targets.append(contentsOf: [
        .target(
          name: "OpenTracingShim",
          dependencies: [
            "OpenTelemetrySdk",
            .product(
              name: "Opentracing",
              package: "opentracing-objc",
              condition: .whenTrait(PackageTraitName.openTracing)
            ),
          ],
          path: "Sources/Importers/OpenTracingShim",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "OpenTracingShimTests",
          dependencies: [
            "SharedTestUtils",
            "OpenTracingShim",
            "OpenTelemetrySdk",
          ],
          path: "Tests/ImportersTests/OpenTracingShim"
        ),
      ])
    #endif

    #if canImport(Darwin)
      dependencies.append(contentsOf: [
        .package(
          url: "https://github.com/undefinedlabs/Thrift-Swift",
          from: "1.1.1"
        ),
        .package(
          url: "https://github.com/kstenerud/KSCrash.git",
          .upToNextMinor(from: "2.6.0")
        ),
      ])
      products.append(contentsOf: [
        .library(name: "JaegerExporter", targets: ["JaegerExporter"]),
        .executable(name: "simpleExporter", targets: ["SimpleExporter"]),
        .library(name: "NetworkStatus", targets: ["NetworkStatus"]),
        .library(
          name: "URLSessionInstrumentation",
          targets: ["URLSessionInstrumentation"]
        ),
        .library(name: "ZipkinExporter", targets: ["ZipkinExporter"]),
        .executable(name: "OTLPExporter", targets: ["OTLPExporter"]),
        .executable(name: "OTLPHTTPExporter", targets: ["OTLPHTTPExporter"]),
        .library(name: "SignPostIntegration", targets: ["SignPostIntegration"]),
        .library(name: "ResourceExtension", targets: ["ResourceExtension"]),
        .library(
          name: "MetricKitInstrumentation",
          targets: ["MetricKitInstrumentation"]
        ),
        .library(name: "Crash", targets: ["Crash"]),
      ])
      targets.append(contentsOf: [
        .target(
          name: "JaegerExporter",
          dependencies: [
            "OpenTelemetrySdk",
            .product(
              name: "Thrift",
              package: "Thrift-Swift",
              condition: .whenTrait(
                PackageTraitName.jaeger,
                platforms: [.iOS, .macOS, .tvOS, .macCatalyst, .linux]
              )
            ),
          ],
          path: "Sources/Exporters/Jaeger"
        ),
        .testTarget(
          name: "JaegerExporterTests",
          dependencies: [
            "JaegerExporter",
            "SharedTestUtils",
          ],
          path: "Tests/ExportersTests/Jaeger"
        ),
        .executableTarget(
          name: "SimpleExporter",
          dependencies: [
            "OpenTelemetrySdk",
            "StdoutExporter",
            "JaegerExporter",
            "ZipkinExporter",
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
          linkerSettings: [
            .linkedFramework("CoreTelephony", .when(platforms: [.iOS]))
          ]
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
          dependencies: [
            "OpenTelemetrySdk",
            "NetworkStatus",
          ],
          path: "Sources/Instrumentation/URLSession",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "URLSessionInstrumentationTests",
          dependencies: [
            "URLSessionInstrumentation",
            "SharedTestUtils",
          ],
          path: "Tests/InstrumentationTests/URLSessionTests"
        ),
        .executableTarget(
          name: "NetworkSample",
          dependencies: [
            "URLSessionInstrumentation",
            "StdoutExporter",
          ],
          path: "Examples/Network Sample",
          exclude: ["README.md"]
        ),
        .target(
          name: "ZipkinExporter",
          dependencies: [
            "OpenTelemetrySdk"
          ],
          path: "Sources/Exporters/Zipkin"
        ),
        .testTarget(
          name: "ZipkinExporterTests",
          dependencies: [
            "ZipkinExporter",
            "SharedTestUtils",
          ],
          path: "Tests/ExportersTests/Zipkin"
        ),
        .executableTarget(
          name: "OTLPExporter",
          dependencies: [
            "OpenTelemetrySdk",
            "OpenTelemetryProtocolExporterGrpc",
            "StdoutExporter",
            .product(
              name: "GRPC",
              package: "grpc-swift",
              condition: .whenTrait(PackageTraitName.otlpGRPC)
            ),
            .product(
              name: "NIO",
              package: "swift-nio",
              condition: .whenTrait(PackageTraitName.otlpGRPC)
            ),
            "ZipkinExporter",
            "ResourceExtension",
            "SignPostIntegration",
          ],
          path: "Examples/OTLP Exporter",
          exclude: [
            "README.md", "prometheus.yaml", "collector-config.yaml",
            "docker-compose.yaml", "images",
          ]
        ),
        .executableTarget(
          name: "OTLPHTTPExporter",
          dependencies: [
            "OpenTelemetrySdk",
            "OpenTelemetryProtocolExporterHttp",
            "StdoutExporter",
            "ZipkinExporter",
            "ResourceExtension",
            "SignPostIntegration",
          ],
          path: "Examples/OTLP HTTP Exporter",
          exclude: [
            "README.md", "collector-config.yaml", "docker-compose.yaml",
            "prometheus.yaml", "images",
          ]
        ),
        .target(
          name: "SignPostIntegration",
          dependencies: [
            "OpenTelemetrySdk"
          ],
          path: "Sources/Instrumentation/SignPostIntegration",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "SignPostIntegrationTests",
          dependencies: [
            "SignPostIntegration",
            "InMemoryExporter",
            "OpenTelemetrySdk",
          ],
          path: "Tests/InstrumentationTests/SignPostIntegrationTests"
        ),
        .target(
          name: "ResourceExtension",
          dependencies: [
            "OpenTelemetrySdk"
          ],
          path: "Sources/Instrumentation/SDKResourceExtension",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "ResourceExtensionTests",
          dependencies: [
            "SharedTestUtils",
            "ResourceExtension",
            "OpenTelemetrySdk",
          ],
          path: "Tests/InstrumentationTests/SDKResourceExtensionTests"
        ),
        .target(
          name: "MetricKitInstrumentation",
          dependencies: [
            "OpenTelemetrySdk"
          ],
          path: "Sources/Instrumentation/MetricKit",
          exclude: ["README.md"]
        ),
        .testTarget(
          name: "MetricKitInstrumentationTests",
          dependencies: [
            "MetricKitInstrumentation",
            "InMemoryExporter",
            "OpenTelemetrySdk",
          ],
          path: "Tests/InstrumentationTests/MetricKitTests"
        ),
        .executableTarget(
          name: "PrometheusSample",
          dependencies: [
            "OpenTelemetrySdk",
            "PrometheusExporter",
          ],
          path: "Examples/Prometheus Sample",
          exclude: ["README.md"]
        ),
        .target(
          name: "Crash",
          dependencies: [
            "OpenTelemetryApi",
            "OpenTelemetrySdk",
            "Sessions",
            .product(
              name: "Installations",
              package: "KSCrash",
              condition: .whenTrait(PackageTraitName.crashReporting)
            ),
            .product(
              name: "Filters",
              package: "KSCrash",
              condition: .whenTrait(PackageTraitName.crashReporting)
            ),
            .product(
              name: "DemangleFilter",
              package: "KSCrash",
              condition: .whenTrait(PackageTraitName.crashReporting)
            ),
            .product(
              name: "Report",
              package: "KSCrash",
              condition: .whenTrait(PackageTraitName.crashReporting)
            ),
          ],
          path: "Sources/Instrumentation/Crash"
        ),
        .testTarget(
          name: "CrashTests",
          dependencies: [
            "Crash",
            "Sessions",
            "InMemoryExporter",
            "SharedTestUtils",
            "OpenTelemetrySdk",
          ],
          path: "Tests/InstrumentationTests/CrashTests"
        ),
      ])
    #endif

    return self
  }
}

if ProcessInfo.processInfo.environment["OTEL_ENABLE_SWIFTLINT"] != nil {
  package.dependencies.append(contentsOf: [
    .package(
      url: "https://github.com/SimplyDanny/SwiftLintPlugins",
      from: "0.57.1"
    )
  ])

  for target in package.targets {
    target.plugins = [
      .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
    ]
  }
}
