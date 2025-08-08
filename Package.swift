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
    .library(name: "OpenTelemetryAtomicInt32", targets: ["OpenTelemetryAtomicInt32"]),
    .library(name: "StdoutExporter", targets: ["StdoutExporter"]),
    .library(name: "PersistenceExporter", targets: ["PersistenceExporter"]),
    .library(name: "InMemoryExporter", targets: ["InMemoryExporter"]),
    .executable(name: "LoggingTracer", targets: ["LoggingTracer"]),
    .executable(name: "ConcurrencyContext", targets: ["ConcurrencyContext"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0"),
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
        "OpenTelemetryAtomicInt32"
      ]
    ),
    .target(
        name: "OpenTelemetryAtomicInt32"
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
      name: "InMemoryExporterTests",
      dependencies: ["InMemoryExporter"],
      path: "Tests/ExportersTests/InMemory"
    ),
    .testTarget(
      name: "PersistenceExporterTests",
      dependencies: ["PersistenceExporter"],
      path: "Tests/ExportersTests/PersistenceExporter"
    ),
    
    .executableTarget(
      name: "LoggingTracer",
      dependencies: ["OpenTelemetryApi"],
      path: "Examples/Logging Tracer"
    ),
    
    .executableTarget(
      name: "ConcurrencyContext",
      dependencies: ["OpenTelemetrySdk", "OpenTelemetryConcurrency", "StdoutExporter"],
      path: "Examples/ConcurrencyContext"
    )
    
  ]
)

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
