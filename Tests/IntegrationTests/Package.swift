// swift-tools-version:6.0
import PackageDescription

// Standalone package so the root `swift test` never picks these targets up:
// the assertions only make sense after Scripts/run-integration-tests.sh has
// driven the demo app against the OpenTelemetry Collector.
let package = Package(
  name: "opentelemetry-swift-integration-tests",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "IntegrationStatusServer", targets: ["IntegrationStatusServer"])
  ],
  dependencies: [
    .package(name: "opentelemetry-swift", path: "../.."),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.3")
  ],
  targets: [
    .executableTarget(
      name: "IntegrationStatusServer",
      dependencies: [
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio")
      ],
      path: "StatusServer"
    ),
    // The assertions decode the collector's output with the generated OTLP
    // structs from OpenTelemetryProtocolExporterCommon, reached through the
    // HTTP exporter product.
    .testTarget(
      name: "IntegrationTests",
      dependencies: [
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift")
      ],
      path: "Assertions"
    )
  ]
)
