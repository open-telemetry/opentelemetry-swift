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
    .library(name: "OpenTelemetrySdk", targets: ["OpenTelemetrySdk"]),
  ],
  targets: [

    .target(
      name: "OpenTelemetryApi",
      dependencies: []
    ),
    .testTarget(
      name: "OpenTelemetryApiTests",
      dependencies: ["OpenTelemetryApi", "OpenTelemetryTestUtils"],
      path: "Tests/OpenTelemetryApiTests"
    ),

    .target(
      name: "OpenTelemetrySdk",
      dependencies: [
        "OpenTelemetryApi",
        "OpenTelemetryAtomicInt32"
      ]
    ),
    .testTarget(
      name: "OpenTelemetrySdkTests",
      dependencies: [
        "OpenTelemetrySdk",
        "OpenTelemetryTestUtils",
      ],
      path: "Tests/OpenTelemetrySdkTests"
    ),

    .target(
        name: "OpenTelemetryAtomicInt32"
    ),

    .target(
      name: "OpenTelemetryTestUtils",
      dependencies: ["OpenTelemetryApi", "OpenTelemetrySdk"]
    ),    
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
